  macro "AutoHyperstackReg" {
      //v1.1: now working with ROIs; better z alignment
      Stack.getPosition(channel, slice, anchorFrame);
      Stack.getDimensions(width, height, channels, slices, frames);
      getVoxelSize(pixelWidth, pixelHeight, voxelDepth, unit);
      title=getTitle();
      if (slices>1 || channels>1) {
          Dialog.create("AutoRegistration options");
              if (channels>1) Dialog.addNumber("Reference channel:", channel);
              if (selectionType==0) Dialog.addCheckbox("Use only selection as reference", 1);
              Dialog.addCheckbox("Correct lateral drift:", 1);
              if (slices>1) Dialog.addCheckbox("Correct focus drift:", 1);
              if (slices>1) Dialog.addCheckbox("Generate a Max projection preview of the result", 1);
          Dialog.show();
          if (channels>1) refChannel=Dialog.getNumber();
          else refChannel=1;
          if (selectionType==0) ROIref=Dialog.getCheckbox();
          else ROIref=0;
          xyCorrect=Dialog.getCheckbox();
          if (slices>1) zCorrect=Dialog.getCheckbox();
          else zCorrect=0;
          if (slices>1) displayPreview=Dialog.getCheckbox();
          else displayPreview=0;
      }
      else { 
          refChannel=1;
          xyCorrect=1;
          zCorrect=0;
          displayPreview=0;
          ROIref=0;
      }
      if (xyCorrect==0 && zCorrect==0) exit;
      setBatchMode(true);
      selectWindow(title);
      setBatchMode("hide");

//Get LUTs and metadata
      REDS=newArray(channels*256);
      GREENS=newArray(channels*256);
      BLUES=newArray(channels*256);
      MINSMAXS=newArray(channels*2);
      index=0;
      for (c=1; c<=channels; c++) {
          Stack.setChannel(c);
          getLut(reds, greens, blues);
          for (n=0; n<256; n++) REDS[n+index*256]=reds[n];
          for (n=0; n<256; n++) GREENS[n+index*256]=greens[n];
          for (n=0; n<256; n++) BLUES[n+index*256]=blues[n];
          getMinAndMax(MINSMAXS[index*2], MINSMAXS[1+index*2]);
          index=index+1;
      }
      Stack.setSlice(1);
      Stack.setChannel(1);
      metadata=newArray(frames);
      for (t=1; t<=frames; t++) {
         Stack.setFrame(t);
          metadata[t-1]=getMetadata("Label");
      }
      if (ROIref==1) getSelectionBounds(ROIrefX, ROIrefY, ROIrefWidth, ROIrefHeight);
      run("Select None");

//Correct XY - preparing reference and doing registration
      if (xyCorrect==1) {
          showStatus("!Performing lateral drift registration");
          if (slices>1) {
              run("Z Project...", "projection=[Sum Slices] all");
              selectWindow("SUM_"+title);
              run("Duplicate...", "title=ref duplicate channels="+refChannel+"-"+refChannel+" slices=1-1 frames=1-"+frames);
              selectWindow("SUM_"+title);
              close();
          }
          else if (channels>1) run("Duplicate...", "title=ref duplicate channels="+refChannel);
          else run("Duplicate...", "title=ref duplicate");
          selectWindow("ref");
          if (ROIref==1) {
              makeRectangle(ROIrefX, ROIrefY, ROIrefWidth, ROIrefHeight);
              run("Crop");
          }
          //normalising signal accross all frames in the reference in case of bleaching
          Stack.setFrame(anchorFrame);
          List.setMeasurements;
          signalNorm=List.getValue("Mean");
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              List.setMeasurements;
              correctionFactor=signalNorm/List.getValue("Mean");
              run("Multiply...", "value="+correctionFactor+" slice");
          }
          Stack.setFrame(anchorFrame);
          run("Enhance Contrast", "saturated=15");
          run("8-bit");
          run("16-bit");
          Stack.getDimensions(refWidth, refHeight, irrelevant, irrelevant, irrelevant);
          makeOval((refWidth/2-6), (refHeight/2-4), 9, 9);
          run("Multiply...", "value=0 stack");
          run("Add...", "value=320 stack");
          Stack.setPosition(1, 1, anchorFrame);
          run("MultiStackReg", "stack_1=ref action_1=Align file_1=[] stack_2=None action_2=Ignore file_2=[] transformation=Translation");
          run("Select None");
          run("Subtract...", "value=290 stack");
          invertSlicesFrames=0;
          centerOfMassX=newArray(frames);
          centerOfMassY=newArray(frames);
          run("Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1");
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              List.setMeasurements;
              centerOfMassX[t-1]=List.getValue("XM");
              if (isNaN(centerOfMassX[t-1])) centerOfMassX[t-1]=centerOfMassX[t-2];
              centerOfMassY[t-1]=List.getValue("YM");
              if (isNaN(centerOfMassY[t-1])) centerOfMassY[t-1]=centerOfMassY[t-2];
          }
          anchorFrameX=centerOfMassX[anchorFrame-1];
          anchorFrameY=centerOfMassY[anchorFrame-1];
          for (t=1; t<=frames; t++) {
              centerOfMassX[t-1]=centerOfMassX[t-1]-anchorFrameX;
              centerOfMassY[t-1]=centerOfMassY[t-1]-anchorFrameY;
          }
         selectWindow("ref");
         close();

//Correct XY - translations
          selectWindow(title);
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              showStatus("!Correcting lateral drift, frame "+t+"/"+frames);
              for (c=1; c<=channels; c++) {
                  Stack.setChannel(c);
                  for (z=1; z<=slices; z++) {
                      Stack.setSlice(z);
                      run("Translate...", "x="+centerOfMassX[t-1]+" y="+centerOfMassY[t-1]+" interpolation=Bicubic slice");
                  }
              }
          }
      }

//Correct Z - preparing reference 1 (left reslice) and doing registration
      if (zCorrect==1) {
          showStatus("!Performing focus drift registration");
          if (ROIref==0) makeRectangle(round(width*0.35), 0, round(width*0.3), height);
          else makeRectangle(ROIrefX, ROIrefY, ROIrefWidth, ROIrefHeight);
          run("Reslice [/]...", "output="+pixelWidth+" start=Left avoid");
          selectWindow("Reslice of "+title);
          run("Z Project...", "projection=[Sum Slices] all");
          selectWindow("Reslice of "+title);
          close();
          selectWindow("SUM_Reslice of "+title);
          run("Duplicate...", "title=ref duplicate channels="+refChannel+"-"+refChannel+" slices=1-1 frames=1-"+frames+"");
          selectWindow("SUM_Reslice of "+title);
          close();
          selectWindow("ref");
          //normalising signal accross all frames in the reference in case of bleaching
          Stack.setFrame(anchorFrame);
          List.setMeasurements;
          signalNorm=List.getValue("Mean");
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              List.setMeasurements;
              correctionFactor=signalNorm/List.getValue("Mean");
              run("Multiply...", "value="+correctionFactor+" slice");
          }
          Stack.setFrame(anchorFrame);
          run("Enhance Contrast", "saturated=15");
          run("8-bit");
          run("16-bit");
          Stack.getDimensions(refWidth, refHeight, irrelevant, irrelevant, irrelevant);
          //registration on reslices works much without interpolation (isotropic resolution) => resize the reference
          run("Size...", "width=refWidth height="+refHeight*voxelDepth/pixelHeight+" average interpolation=Bicubic");
          makeOval((refWidth/2-2), ((refHeight*voxelDepth/pixelHeight)/2-2), 5, 5);
          run("Multiply...", "value=0 stack");
          run("Add...", "value=320 stack");
          run("Select None");
          Stack.setPosition(1, 1, anchorFrame);
          run("MultiStackReg", "stack_1=ref action_1=Align file_1=[] stack_2=None action_2=Ignore file_2=[] transformation=Translation");
          run("Subtract...", "value=290 stack");
          centerOfMassY2=newArray(frames);
          run("Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1");
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              List.setMeasurements;
              centerOfMassY2[t-1]=List.getValue("YM")/(voxelDepth/pixelHeight); //resize back the y coordinate because resized the reference
              if (isNaN(centerOfMassY2[t-1])) centerOfMassY2[t-1]=centerOfMassY2[t-2];
          }
          anchorFrameY=centerOfMassY2[anchorFrame-1];
          for (t=1; t<=frames; t++) centerOfMassY2[t-1]=centerOfMassY2[t-1]-anchorFrameY;
          selectWindow("ref");
          close();

//Correct Z - preparing reference 2 (top reslice) and doing registration
          selectWindow(title);
          run("Select None");
          run("Reslice [/]...", "output="+pixelWidth+" start=Top avoid");
          selectWindow(title);
          close();
          selectWindow("Reslice of "+title);
          rename(title);
          if (ROIref==0) run("Z Project...", "start="+round(height*0.35)+" stop="+round(height*0.65)+" projection=[Sum Slices] all");
          else {
              run("Z Project...", "start="+ROIrefY+" stop="+height-ROIrefHeight+" projection=[Sum Slices] all");
              selectWindow("SUM_"+title);
              makeRectangle(ROIrefX, 0, ROIrefWidth, slices);
              run("Crop");
          }
          selectWindow("SUM_"+title);
          run("Duplicate...", "title=ref duplicate channels="+refChannel+"-"+refChannel+" slices=1-1 frames=1-"+frames+"");
          selectWindow("SUM_"+title);
          close();
          selectWindow("ref");
          //normalising signal accross all frames in the reference in case of bleaching
          Stack.setFrame(anchorFrame);
          List.setMeasurements;
          signalNorm=List.getValue("Mean");
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              List.setMeasurements;
              correctionFactor=signalNorm/List.getValue("Mean");
              run("Multiply...", "value="+correctionFactor+" slice");
          }
          Stack.setFrame(anchorFrame);
          run("Enhance Contrast", "saturated=15");
          run("8-bit");
          run("16-bit");
          Stack.getDimensions(refWidth, refHeight, irrelevant, irrelevant, irrelevant);
          //registration on reslices works much without interpolation (isotropic resolution) => resize the reference
          run("Size...", "width=refWidth height="+refHeight*voxelDepth/pixelWidth+" average interpolation=Bicubic");
          makeOval((refWidth/2-2), ((refHeight*voxelDepth/pixelWidth)/2-2), 5, 5);
          run("Multiply...", "value=0 stack");
          run("Add...", "value=320 stack");
          run("Select None");
          Stack.setPosition(1, 1, anchorFrame);
          run("MultiStackReg", "stack_1=ref action_1=Align file_1=[] stack_2=None action_2=Ignore file_2=[] transformation=Translation");
          run("Subtract...", "value=290 stack");
          centerOfMassY=newArray(frames);
          run("Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1");
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              List.setMeasurements;
              centerOfMassY[t-1]=List.getValue("YM")/(voxelDepth/pixelWidth); //resize back the y coordinate because resized the reference
              if (isNaN(centerOfMassY[t-1])) centerOfMassY[t-1]=centerOfMassY[t-2];
          }
          anchorFrameY=centerOfMassY[anchorFrame-1];
          for (t=1; t<=frames; t++) centerOfMassY[t-1]=centerOfMassY[t-1]-anchorFrameY;
          selectWindow("ref");
          close();

//Correct Z - averaging and applying the 2 registrations
          for (t=1; t<=frames; t++) centerOfMassY[t-1]=(centerOfMassY[t-1]+centerOfMassY2[t-1])/2;
          selectWindow(title);
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              showStatus("!Correcting focus drift, frame "+t+"/"+frames);
              for (c=1; c<=channels; c++) {
                  Stack.setChannel(c);
                  for (z=1; z<=height; z++) {
                      Stack.setSlice(z);
                      run("Translate...", "x=0 y="+centerOfMassY[t-1]+" interpolation=Bicubic slice");
                  }
              }
          }
          rename("resliceAligned");
          run("Reslice [/]...", "output="+pixelWidth+" start=Top avoid");
          selectWindow("resliceAligned");
          close();
          selectWindow("Reslice of resliceAligned");
          rename(title+"_aligned");
      }
      else rename(title+"_aligned");

      //applying original LUTs to the aligned stack
      index=0;
      for (c=1; c<=channels; c++) {
          Stack.setChannel(c);
          for (n=0; n<256; n++) reds[n]=REDS[n+index*256];
          for (n=0; n<256; n++) greens[n]=GREENS[n+index*256];
          for (n=0; n<256; n++) blues[n]=BLUES[n+index*256];
          setLut(reds, greens, blues);
          setMinAndMax(MINSMAXS[index*2], MINSMAXS[1+index*2]);
          index=index+1;
      }
      for (t=1; t<=frames; t++) {
          Stack.setFrame(t);
          for (c=1; c<=channels ; c++) {
              Stack.setChannel(c);
              for (z=1 ; z<=slices; z++) {
                  Stack.setSlice(z);
                  setMetadata("Label", metadata[t-1]);
              }
          }
      }
      //Generating MaxProj preview
      if (displayPreview==1) {
          showStatus("!Generating the preview");
          run("Z Project...", "projection=[Max Intensity] all");
          selectWindow(title+"_aligned");
          makeRectangle(0, round(height*0.4), width, round(height*0.2));
          run("Reslice [/]...", "output="+pixelWidth*5+" start=Top");
          selectWindow(title+"_aligned");
          run("Select None");
          selectWindow("Reslice of "+title+"_aligned");
          run("Z Project...", "projection=[Max Intensity] all");
          selectWindow("Reslice of "+title+"_aligned");
          close();
          selectWindow("MAX_Reslice of "+title+"_aligned");
          Stack.getDimensions(irrelevant, resliceHeight, irrelevant, irrelevant, irrelevant);
          run("Canvas Size...", "width="+width+" height="+resliceHeight+3+" position=Bottom-Left zero");
          run("Combine...", "stack1=[MAX_"+title+"_aligned] stack2=[MAX_Reslice of "+title+"_aligned] combine");
          selectWindow("Combined Stacks");
          rename(title+"_aligned_MAX");
          index=0;
          for (c=1; c<=channels; c++) {
              Stack.setChannel(c);
              for (n=0; n<256; n++) reds[n]=REDS[n+index*256];
              for (n=0; n<256; n++) greens[n]=GREENS[n+index*256];
              for (n=0; n<256; n++) blues[n]=BLUES[n+index*256];
              setLut(reds, greens, blues);
              setMinAndMax(MINSMAXS[index*2], MINSMAXS[1+index*2]);
              index=index+1;
              run("Enhance Contrast", "saturated=0.5");
          }
          for (t=1; t<=frames; t++) {
              Stack.setFrame(t);
              for (c=1; c<=channels ; c++) {
                  Stack.setChannel(c);
                  setMetadata("Label", metadata[t-1]);
              }
          }
          selectWindow(title+"_aligned");
      }
      setBatchMode("exit and display");
      showStatus("Done!");
  }
