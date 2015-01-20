//
//  main.m
//  image2pict1
//
//  Created by Steven Troughton-Smith on 20/01/2015.
//  Copyright (c) 2015 High Caffeine Content. All rights reserved.
//

#import <AppKit/AppKit.h>

typedef struct _Frame {
	int16_t x;
	int16_t y;
	int16_t x2;
	int16_t y2;
} Frame;

/* QuickDraw PICT v1.0 Opcodes */
#define clpRegion 0x01
#define picVersion 0x11

#define BitsRect 0x90
#define PackBitsRect 0x98

#define EndOfPicture 0xff

#define HI(num) (((num) & 0x0000FF00) >> 8)
#define LO(num) ((num) & 0x000000FF)

FILE *fout;

Frame FrameMake(x,y,x2,y2)
{
	Frame f;
	f.x = x;
	f.y = y;
	f.x2 = x2;
	f.y2 = y2;
	return f;
}

void WriteWord(int16_t word)
{
	fputc(HI(word), fout);
	fputc(LO(word), fout);
}

void WriteFrame(Frame f)
{
	// top, left, bottom, right
	WriteWord(f.y);
	WriteWord(f.x);
	WriteWord(f.y2);
	WriteWord(f.x2);
}

void WriteByte(int8_t byte)
{
	fputc(byte, fout);
}

void WritePicVersion(int8_t version)
{
	WriteByte(picVersion);
	WriteByte(version);
}

void WriteClipRegion(Frame f)
{
	WriteByte(clpRegion);
	WriteWord(10);
	WriteFrame(f);
}

void WriteEndOfPicture()
{
	WriteByte(EndOfPicture);
}

void WriteHeader()
{
	for (int i =0; i < 512; i++) // 512-byte blank header
	{
		WriteByte(0);
	}
}

void print_usage()
{
	printf("image2pict1 1.0\n");
	printf("Converts images to PICT format version 1.0\n\n");
	printf("Usage: image2pict1 input[.jpg|.png|...] output.pct\n");
}

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		
		if (argc < 3)
		{
			print_usage();
			return -1;
		}
		
		NSString *inputFile = [NSString stringWithUTF8String:argv[1]];
		NSString *outputFile = [NSString stringWithUTF8String:argv[2]];
		
		NSImage *sourceImage = [[NSImage alloc] initWithContentsOfFile:inputFile];
		
		if (!sourceImage)
		{
			printf("Error: could not open %s for reading\n", [inputFile UTF8String]);
			return -1;
		}
		
		/* Ugh, DPI */
		NSBitmapImageRep *rep = [[sourceImage representations] objectAtIndex: 0];
		[sourceImage setSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])];
		
		NSBitmapImageRep* raw_img = [NSBitmapImageRep imageRepWithData:[sourceImage TIFFRepresentation]];
		
		Frame pictureFrame = FrameMake(0, 0, (int16_t)sourceImage.size.width, (int16_t)sourceImage.size.height);
		
		fout = fopen([outputFile UTF8String], "w");
		
		int canvasWidth = (int)sourceImage.size.width;
		int canvasHeight = (int)sourceImage.size.height;
		
		/* Since we're chunking the image into 32x32 pieces, add padding if image size not divisible */
		canvasWidth = ceil((float)canvasWidth/32.0)*32;
		canvasHeight = ceil((float)canvasHeight/32.0)*32;

		if (fout != NULL) {
			WriteHeader();
			WriteWord(0);
			
			WriteFrame(pictureFrame);
			WritePicVersion(1);
			WriteClipRegion(pictureFrame);
			
			int chunkPxSize = 32;
			int bpp = 1;
			int bpr = bpp * chunkPxSize / 8;
			
			for (int y = 0; y < canvasHeight; y+=32)
			{
				for (int x = 0; x < canvasWidth; x+=32)
				{
					/* Check if chunk has worthwhile pixels */
					BOOL ignoreChunk = YES;
					
					for (int yy = 0; yy < chunkPxSize; yy++)
					{
						for (int xx = 0; xx < chunkPxSize; xx++)
						{
							NSColor* color = [raw_img colorAtX:x+xx y:y+yy];
							
							if (color.brightnessComponent < 0.98)
							{
								ignoreChunk = NO;
								break;
							}
						}
					}
					
					if (!ignoreChunk)
					{
						WriteByte(BitsRect);
						WriteWord(bpr); // bpr
						WriteFrame(FrameMake(0, 0, chunkPxSize, chunkPxSize)); // bounds
						WriteFrame(FrameMake(0, 0, chunkPxSize, chunkPxSize)); // src
						WriteFrame(FrameMake(x, y, x+chunkPxSize, y+chunkPxSize)); // dest
						WriteWord(0); // mode=srcCpy
						
						for (int yy = 0; yy < chunkPxSize; yy++)
						{
							for (int xx = 0; xx < chunkPxSize/8; xx++)
							{
								uint8_t eightpixels = 0;
								
								for (int bit = 0; bit < 8; bit++)
								{
									eightpixels = eightpixels << 1;
									
									if ((x+(xx*8)+bit) <= (int)sourceImage.size.width && y+yy <= (int)sourceImage.size.height)
									{
										NSColor* color = [raw_img colorAtX:x+(xx*8)+bit y:y+yy];
										
										if (color.brightnessComponent < 0.98)
										{
											eightpixels |= 1;
										}
									}
									
								}
								WriteByte(eightpixels);
							}
						}
					}
				}
			}
			
			WriteEndOfPicture();
			
			fclose (fout);
		}
		else
		{
			printf("Error: could not open %s for writing\n", [outputFile UTF8String]);
			return -1;
		}
		
	}
	return 0;
}