pdfSplit
========

Script to split PDF files that were generated out of images into smaller PDF files based on a control file

### Introduction
This script was written to split the PDF files for the ML WikiSource digitization competition. Students from many schools are participating in this event. The the text to be digitized are available in PDF files and these files need to be split across schools based on the number of students participating from each school. The PDF files contain the scanned images of the books.

### Running the script
The script uses a control file to split the PDF files. The control file contains school code and number of students participating separated by commas.

./splitPdf.sh  -c controlFile -f FolderContainingSourcePDFs -p pagesPerStudent -o OutputFolder -t TempFolder

#### Options
-c : Control file in CSV format. Contains School code and number of students.
-f : The folder containing source PDF files.
-p : Pages to be allocated per student.
-o : Output directory where the smaller PDF files will be created. The output file name has the format :SchoolCode_NameOfSourcePDF_StartingPage_EndingPage.pdf
-t : Temp directory for PDF files and images
-h : Displays help message.
-d : Enables debug messages.



