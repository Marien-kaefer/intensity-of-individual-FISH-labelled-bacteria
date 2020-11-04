// Macro to identify individual FISH labelled bacteria and measure their intensity levels
// Make sure the image files are two channel z stacks with the fluorescence in channel 1
// Hard coded parameters: 
// 		- the images are filtered for areas with small bacterial clusters of up to 4 um^2  
//		- the find maxima prominence is set to 2500 --> 16 bit data required
//
//												- Written by Marie Held [mheldb@liverpool.ac.uk] October 2020
//												  Liverpool CCI (https://cci.liv.ac.uk/)

//get input and output directories from user
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory - can be same as input", style = "directory") output
#@ String (label = "File suffix", value = ".lsm") suffix

setBatchMode(true);

processFolder(input);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}

function processFile(input, output, file) {

	//print("Processing: " + input + File.separator + file);
	print("Processing folder: " + input);
	print("Processing: " + file);
	open(input + File.separator + file);
	Image_Title = getTitle();
	//debug only
	//print("Image Title: " + Image_Title);
	Channel1_Image = "C1-" + Image_Title;
	//print("Channel 1 image: " + Channel1_Image);
	Channel2_Image = "C2-" + Image_Title;
	//print("Channel 1 image: " + Channel2_Image);

	Image_Title_Without_Extension = file_name_remove_extension(Image_Title);

	results_directory = output + File.separator + Image_Title_Without_Extension + "-results";
	File.makeDirectory(results_directory); 

	//split channels and close transmitted light channel
	run("Split Channels");
	selectImage(Channel2_Image);
	close();
	selectWindow(Channel1_Image);

	//maximum intensity projection of the fluorescence channel
	run("Z Project...", "projection=[Max Intensity]");

	//save maximum intensity projection of fluorescence channel
	Maximum_Intensity_Projection_Image = "MAX_C1-" + Image_Title_Without_Extension + ".tif";
	//debug only
	//print("MIP image name: " + Maximum_Intensity_Projection_Image);
	saveAs("Tiff", results_directory + File.separator + Maximum_Intensity_Projection_Image);
	run("Duplicate...", " ");


	//threshold maximum intensity projection image
	setAutoThreshold("RenyiEntropy dark");

	// make thresholded image binary
	run("Convert to Mask");

	// connected component analysis, filter clusters by size, only keep ROIs up to 4 um^2
	run("Analyze Particles...", "size=0.00-4.00 show=Outlines clear exclude add");
	//save set of ROIs up to 4 um^2
	roiManager("Save", results_directory + File.separator + Image_Title_Without_Extension + "-selected-clusters-ROI-set.zip");

	// delete intensities outside of the ROIs of up to 4 um^2
	selectWindow(Maximum_Intensity_Projection_Image);
	run("Select All");
	roiManager("Add");
	roiManager("XOR");
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	run("Make Inverse");
	run("Clear Outside");
	roiManager("Select", roiManager("count")-2);
	roiManager("Show None");
	roiManager("Deselect");
	roiManager("Delete");

	//save ROIs content of maximum intensity projection of fluorescence channel 
	saveAs("Tiff", results_directory + File.separator + "MAX_C1-" + Image_Title_Without_Extension + "-selected-clusters.tif");
	
	// find maxima as an approximation of individual bacteria. Prominence set to 2500 - information on prominence, see here: https://forum.image.sc/t/new-maxima-finder-menu-in-fiji/25504/5
	run("Find Maxima...", "prominence=2500 output=[Maxima Within Tolerance]");

	// connected component analysis, create regions of interest for all maxima found
	run("Analyze Particles...", "size=0-Infinity show=Outlines clear exclude add");

	//close results table
   	if (isOpen("Results")) {
    	selectWindow("Results");
       	run("Close");
   	}
   
	selectWindow("MAX_C1-" + Image_Title_Without_Extension + "-selected-clusters.tif");
	roiManager("Show All");
	run("Set Measurements...", "area mean display redirect=None decimal=3");
	roiManager("Measure");
	saveAs("Results", results_directory + File.separator + Image_Title_Without_Extension + "-mean-intensities.txt");
	roiManager("Save", results_directory + File.separator + Image_Title_Without_Extension + "-measured-ROI-set.zip");

	//tidy up
	// close all images
	close("*");
	// empty the ROI manager
	roiManager("reset");
	// empty the results table
	run("Clear Results");
	//close results table
   	if (isOpen("Results")) {
       selectWindow("Results");
       run("Close");
   	}
	
	//user notification
	//print("Finished processing: " + input + File.separator + file);
	print("Finished processing: " + file);
}

function file_name_remove_extension(file_name){
	dotIndex = indexOf(file_name, "." );
	file_name_without_extension = substring(file_name, 0, dotIndex );
	//print( "Name without extension: " + file_name_without_extension );
	return file_name_without_extension;
}

print("All done!")