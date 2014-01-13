#! /usr/bin/bash

# Script to build smaller pdf files from pdf files in a given folder.
# 
# Extract the images from the original pdf
# Reduce the quality of the images to 10%
# Generate pdf files with 10 or 15 images.
# Combine all the pdf files generated in the previous step
# Requirements / Dependencies
# 	1. Requires convert utility from ImageMagick suite
#	2. Requires pdfunite from poppler package
#	3. Need sufficient space in the directory pointed by imgF
#		which points to /tmp/imgs
# Assumptions:
# 	1. Pdf files are generated out of images and do not contain text.
#	2. The required data is in the extracted jpg files and not in ppm files


# The control csv has the school code and the number of students.
# The fields are comma separated and records are separated by new lines.

# Prime Jyothi (primejyothi at gmail dot com), 20140112
# License GPLv3

function log ()
{
	echo "Log : $@"
}

function err ()
{
	echo "Error : $@"
}

function dbg ()
{
	if [[ -z "$dbgFlag" ]]
	then
		return
	fi
	echo "Debug : $@"
}

function help ()
{
	echo "Usage `basename $0` [-d] [-h] -c ContorlFile -f PDF Folder -p Pages per Student -q image quality"
	echo -e "\t -d : Enable debug messages"
	echo -e "\t -h : Display this help message"
}

function createPdfs ()
{
	del="$*"
	log $LINENO  "Converting images to PDFs"
	pdfPartName=`basename $currentPDF .pdf`

	# newName=${schoolCode}_${pdfPartName}_${startPage}_${currentPage}
	# Set the page numbers in 4 digits, otherwise the ordering will be
	# lost when ls uses dictionary sorting.
	pgNo=`printf %04d $currentPage`
	newName=${schoolCode}_${pdfPartName}_${pgNo}

	dbg "$LINENO New name [$newName]"
	convert $del ${imgPDF}/${newName}.pdf
	dbg $LINENO  "Deleting [$del]"
	rm $del
}

function splitPdf ()
{
	num=$1
	pdf2Split=`tail -n +${num} pdf.lst | head -1`
	log "$LINENO  Splitting pdf file [$pdf2Split] into images."
	dbg $LINENO  splitPdf $num
	pdfimages -p -j $pdf2Split $imgF/jj
	currentPDF=$pdf2Split
	rm $imgF/*.ppm
}

function combinePdfs ()
{
	ucount=`ls -1 ${imgPDF}/*.pdf 2> /dev/null | wc -l`

	if [[ "$ucount" -lt "1" ]]
	then
		return

	fi
	log "$LINENO $ucount Combining the PDFs"
	for i in `ls -1 ${imgPDF}/*.pdf`
	do
		log $LINENO File : $i
	done

	pgNo=`printf %04d $currentPage`
	newPDFName=${schoolCode}_${pdfPartName}_${startPage}_${pgNo}
	log $LINENO new name [$newPDFName]

	if [[ "$ucount" -eq 1 ]]
	then
		# Only one PDF file, just move it
		mv  ${imgPDF}/*.pdf ${outPDF}/${newPDFName}.pdf
	else
		pdfunite ${imgPDF}/*.pdf ${outPDF}/${newPDFName}.pdf
		rm  ${imgPDF}/*.pdf
	fi

}

function getImages ()
{
	num=$1
	k=0
	out=""
	for i in `ls -1 $imgF`
	do
		out="$out ${imgF}/$i"
		k=`expr $k + 1`
		if [[ $k -eq $num ]]
		then
			break;
		fi
	done
	out="$k|$out"
	echo $out
}

while getopts c:f:p:q:h:d args
do
	case $args in
	c) ctrlFile="$OPTARG"
		;;
	f) pdfDir="$OPTARG"
		;;
	p) pagePerStudent="$OPTARG"
		;;
	q) imgQlty="$OPTARG"
		;;
	h) help
		exit
		;;
	d)
		dbgFlag=Y
		;;
	*)  help
	esac
done

if [ -z "$ctrlFile" -o -z "$pdfDir" -o -z "$pagePerStudent" ]
then
	help
	exit 2
fi

if [[ ! -r ${ctrlFile} ]]
then
	echo "Unable to read input file ${ctrlFile}"
	exit 2
fi

# Control Parameters

# Temp image folder
imgF="/var/tmp/imgs"
imgPDF="/var/tmp/pdf"
outPDF="/var/tmp/pdf_out"

# Make sure that the temporary directory is cleaned out when interrupted.
# trap "rm -rf ${imgF}; exit 2" 1 2 3 

# Generate list of PDF files.

dbg $LINENO  "Generating pdf list" 
ls ${pdfDir}/*.pdf > pdf.lst

## Program flow:
## Read the control file, get the school code and the student count.
## Calculate the number of pages required by the school.
## Build the PDF file with required number of pages from the images
## available in the $imgF folder.
## If sufficient number of pages(images) are not available, complete current
## pdf file being built and  generate new images from the new PDF file.

# Validate the Control file. If errors are detected while processing the pdf
# files, the error recovery would be too complicated. If there are any
# errors, fail it in the beginning.
errors="no"
log $LINENO  "Validating control file."
totalSchools=0
totalStudents=0
totalPages=0
while read ctrlInfo 
do

	schoolCode=`echo ${ctrlInfo} | awk -F"," '{print $1}'`
	studentCount=`echo ${ctrlInfo} | awk -F"," '{print $2}'`
	pageReq=`expr $studentCount \* $pagePerStudent`
	ret=$?
	if [[ "${ret}" -ne 0 ]]
	then
		# Expr failed, mostly due to invalid student count
		err "Error while processing school : ${schoolCode}"
		errors="Yes"
		continue
	fi
	totalSchools=`expr ${totalSchools} + 1`
	totalStudents=`expr ${totalStudents} + ${studentCount}`
	totalPages=`expr ${totalPages} + ${pageReq}`

done < ${ctrlFile}

if [[ "${errors}" = "Yes" ]]
then
	err $LINENO  "Errors detected in the control file, exiting"
	exit 2
fi

# Check for files from previous runs. If present exit. These files can lead
# to incorrect results. The user has to decide to keep the files or delete.
outFileCount=`ls ${imgPDF}/*.pdf | wc -l`
dbg $LINENO  outFileCount $outFileCount
if [[ "$outFileCount" -gt 0 ]]
then
	err $LINENO "Files present in $imgPDF folder."
	errors="Yes"
fi

outFileCount=`ls ${imgF}/*.jpg | wc -l`
dbg $LINENO  outFileCount $outFileCount
if [[ "$outFileCount" -gt 0 ]]
then
	err $LINENO "Files present in $imgF folder."
	errors="Yes"
fi

if [[ "$errors" = "Yes" ]]
then
	err $LINENO "Files present in $imgPDF / $imgF folder. Remove them to proceed."
	exit 2
fi

log $LINENO  "Totals schools [$totalSchools], students [${totalStudents}] pages [${totalPages}]"
log $LINENO  "Control file validation completed."

batchSize=10
pdfSeq=1
currentPDF=""
currentPage=0
# Read the control file and process the schools one by one.
while read ctrlInfo 
do
	schoolCode=`echo ${ctrlInfo} | awk -F"," '{print $1}'`
	studentCount=`echo ${ctrlInfo} | awk -F"," '{print $2}'`
	pageReq=`expr $studentCount \* $pagePerStudent`
	ret=$?
	if [[ "${ret}" -ne 0 ]]
	then
		# Expr failed, mostly due to invalid student count
		err $LINENO  "Error while processing school : ${schoolCode}"
		continue
	fi

	# Start page for naming the output pdf files.
	startPage=`expr $currentPage + 1`
	log $LINENO "Processing School code [$schoolCode], # of students [${studentCount}] total pages  [$pageReq]"

	# Get required number of pages from the current school.
	pagesProcessed=0
	while :
	do
		# Calculate the fetch size.
		rem=`expr $pageReq \- $pagesProcessed`	
		# dbg $LINENO  rem $rem
		if [ $rem -lt $batchSize -a $rem -gt 0 ]
		then
			dbg "$LINENO Changing fetch size to $rem"
			fetchSize=$rem
		else
			fetchSize=$batchSize
		fi
		dbg $LINENO : fetchSize $fetchSize

		imgRes=`getImages $fetchSize`
		imgCount=`echo $imgRes | cut -d"|" -f 1`
		images=`echo $imgRes | cut -d"|" -f 2`
		dbg $LINENO  imageCount [$imgCount]
		# dbg $LINENO  images $images

		if [[ $imgCount -eq 0 ]]
		then
			# About to start processing new PDF file. Combine the smaller
			# PDFs generated from the previous file.
			log $LINENO  Calling combinePdfs
			combinePdfs
			log $LINENO  "Splitting new PDF into images"
			splitPdf $pdfSeq
			pdfSeq=`expr $pdfSeq + 1`
			currentPage=0
			startPage=1 # New pdf, reset page number.
			continue
		fi

		pagesProcessed=`expr $pagesProcessed + $imgCount`
		currentPage=`expr $currentPage + $imgCount`
		log $LINENO Pages processed : $pagesProcessed

		# convert to mini pdfs
		log $LINENO "Current file [$currentPDF] start page [$startPage] end Page :[$currentPage]"
		log "$LINENO Converting images into PDF."
		createPdfs $images 

		if [[ $pagesProcessed -ge $pageReq ]]
		then
			log "$LINENO pages processed = $pagesProcessed, breaking"
			combinePdfs
			break
		fi

	done
	log "$LINENO Pages Processed $pagesProcessed"


done < ${ctrlFile}
exit
