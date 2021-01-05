# AutoHyperstackReg

## Changelog
* v1.1:
  * A subregion can be used as a reference by tracing a rectangular selection before starting the macro.
  * Fixed multiple issues with z alignment

## Description
AutoHyperstackReg is an ImageJ macro that uses the [TurboReg](http://bigwww.epfl.ch/thevenaz/turboreg/) and [MultiStackReg](http://bradbusse.net/downloads.html) ImageJ plugins to align in xy and z the successive frames of a stack or hyperstack. AutoHyperstackReg automatically performs the following steps used with the [MultiHyperStackReg](https://github.com/nicolasloyer/AutoHyperstackReg/) ImageJ macro: generation of a single slice reference stack; alignment of the reference stack; application of the alignment to the original hyperstack (see the related [JoVE protocol](https://www.jove.com/t/61954/applications-immobilization-drosophila-tissues-with-fibrin-clots-for) for details).

## Installation
* Download [TurboReg](http://bigwww.epfl.ch/thevenaz/turboreg/) and [MultiStackReg](http://bradbusse.net/downloads.html) and put them in the ImageJ plugin folder.
* Download AutoHyperstackReg, open it in ImageJ or a text editor, copy an paste the entire code in the Startup Macros of ImageJ (accessible in the macros folder of ImageJ or from the ImageJ window with Plugins>Macros>Startup Macros), save Startup Macros, reload ImageJ.

## Use
* To only use a subregion as a reference for the alignment, which can drastically speed up the registration and in my experience often makes the alignment better, trace a rectangular selection before starting AutoHyperstackReg. The entire stack will be aligned based on the reference.
* Move the frames scrollbar to the frame to which every other frames will be aligned (this specific frame will not be modified).
* Start AutoHyperstackReg, which should be accessible in Plugins>Macros if AutoHyperstackReg was installed as advised.
* If applicable, choose the reference channel, whether to use a subregion as the reference, whether to align in xy and/or in z and whether to display a max-projected preview of the aligned hyperstack.
* Click "OK" and wait for AutoHyperstackReg to finish the job, which may take some time with large files.
