About
=============

This converts images to 1-bit B&W PICT, QuickDraw picture format version 1.0 (as per Mac OS System 1-6).

Why
=============

System 7 and above support PICTv2, which is still supported by tools such as ImageMagick, GraphicConverter, etc.

Systems 1-6 only support PICTv1; I couldn't find any tools that supported v1 as an output format, so I put this together as per [Apple Technical Note QD14](http://www.idea2ic.com/File_Formats/QuickDraw%20picture%20Format.pdf).

PICTs created by this tool can be successfully used in the resource fork of apps built for System 1-6.

How
=============

I use the CopyBits/BitsRect function of QuickDraw to chunk larger images into 32x32 sections, which seems to be a good way to minimize file size & increase drawing speed.