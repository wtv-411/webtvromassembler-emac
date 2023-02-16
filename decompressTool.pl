#!/usr/bin/perl

use Fcntl 'SEEK_SET';
use warnings;
use strict;
use GetOpt::Long;

use constant PADDING_LEFT => 1;
use constant PADDING_RIGHT => 2;
use constant PADDING_CENTER => 3;

use constant COMP_ZIP => 1;
use constant COMP_LZSS => 2;

my $compUse = 0;
my $inDir = "./in/";
my $outDir = "./out/";
my $outOFileApp = "_approm.o";
my $outOFileBoot = "_bootstraprom.o";

main();

sub main {
	recz(".", "");
}

sub recz
{
	my $dir = shift;
	my $parent_path = shift;

	my $search_path = $dir;
	if($parent_path ne "")
	{
		$search_path = $parent_path . "/" . $dir;
	}

	my $hDIR;
	if(opendir($hDIR, $search_path))
	{
		my $ff = "";
		foreach $ff (readdir($hDIR))
		{
			if($ff ne "." && $ff ne "..")
			{
				if(-d $search_path . "/" . $ff)
				{
					recz($ff, $search_path);
				}
				elsif($ff=~/(\d+)\.b?rom$/)
				{
					$inDir = $search_path . "/";
					$outDir = $outDir;

					print $outDir . "\n";
					
					loadCompModules();
					inflateByBlocks();
					last;
				}
			}
		}
		closedir($hDIR);
	}
}

sub mkdirEx($) {
	my $dirName = shift;

	$dirName=~s/\\/\//g;

	my $partDir = "";
	foreach  (split("/", $dirName)) {
		$partDir .= "$_/";

		if(!-e $partDir){
			if(!mkdir($partDir)){
				return 0;
			}
		}
	}

	return 1;
}

sub exitMe {
	exit(shift);
}

sub printMenu($@) {
	my $fullGlory = shift;
	my $retNum = shift;
	my @menu = @_;

	if($fullGlory){
		system("clear"); system("cls");
		print "=-" x 25 . "\n"; 
			print addPadding("WebTV Build/TellyScript Decompression Tool", PADDING_CENTER, " ", 50) . "\n"; 
		print "=-" x 25 . "\n\n";
	}
	
	print "Please choose one of the options below:\n\n";

	my @mnuOpts = ();
	my @mnuFuncs = ();
	if($retNum){
		@mnuOpts = @menu;
	}else{
		@mnuOpts = grep { 1 if(ref($_) ne "CODE") } @menu;
		@mnuFuncs = grep { 1 if(ref($_) eq "CODE") } @menu;
	}

	my $numOpts = scalar(@mnuOpts);
	my $fat = length(($numOpts + 1) . "") + 2;

	for(my $i = 0; $i < $numOpts; ++$i){
		print addPadding(($i + 1) . ".", PADDING_RIGHT, " ", $fat) . "$mnuOpts[$i]\n";
	}

	print "\n\n";

	print "Your selection: "; chomp(my $sel=<>);

	$sel *= 1;
	if($sel=~/\d*/ && $sel <= $numOpts && $sel > 0){
		if($fullGlory){
			system("clear"); system("cls");
		}

		if($retNum){
			return $sel;
		}else{
			$sel -= 1;
			&{$mnuFuncs[$sel]};
		}
	
	}

}

sub addPadding($$$$) {
	my $data = shift;
	my $padDir = shift; # 1 = Left, 2 = Right, 3 = Both (center data)
	my $padChar = shift;
	my $padLen = shift;

	my $dLen = length($data);
	return substr($data, $padLen) if($dLen > $padLen);
	$padLen = ($padLen - $dLen);

	if($padDir == PADDING_LEFT){
		return ($padChar x $padLen) . $data;
	}elsif($padDir == PADDING_RIGHT){
		return $data . ($padChar x $padLen);
	}elsif($padDir == PADDING_CENTER){
		my $fontAdd = 0;
		++$fontAdd if($padLen % 2);
		$padLen = int($padLen/2);
		return $padChar x ($padLen + $fontAdd) . $data . $padChar x $padLen;
	}else{
		return $data;
	}
}

sub inflateByBlocks {
	opendir(DIR, $inDir);
		my @dirListing = readdir(DIR);
		
		if(scalar(@dirListing) == 2){
			print STDERR "ERROR: There are no files in the input directory! " . (($! ne "") ? $! : "")  . "\n";
			exitMe(1);
		}
		
		@dirListing = grep {/part(\d+)\.(rom|brom)$/i} @dirListing;

		# You may think this is useless but take it out and there will be a speed difference (i.e. slower).
		@dirListing = sort {
			my ($numA) = ($a=~/part(\d+)\.(rom|brom)$/i);
			my ($numB) = ($b=~/part(\d+)\.(rom|brom)$/i);
			
			$numA *= 1;
			$numB *= 1;
		
			return $numA <=> $numB;
		} @dirListing;

		my $outFile = $outOFileApp;
#		if($dirListing[0]=~/part[0-9]+\.rom$/i){
		if($dirListing[0]=~/part000\.rom$/i){
			$outFile = $outOFileApp;
			print "Approm build detected...\n";
#		}elsif($dirListing[0]=~/part[0-9]+\.brom$/i){
		}elsif($dirListing[0]=~/part000\.brom$/i){
			$outFile = $outOFileBoot;
			print "Bootrom build detected...\n";
		}else{
			print STDERR "ERROR: I'm sorry but I couldn't detect the build type in the $inDir directory.  It could be that you have the wrong or no files in this directory.\n";
			pause();
			return;
		}
		$outFile = "$outDir$outFile";

		#decideFile($outFile) if(-e $outFile);
		if(-e $outFile)
		{
			unlink($outFile);
			#return;
		}

		print "\n";

		my %dirList_temp = ();
		my ($lstDis, $bpNum, $bdComp, $bdOff, $bdSiz, $bdUncomSiz, $bdPOff, $writeNum);
		my $curBNum = "";
		my $numWarn = 0;
		foreach  (@dirListing) {
			($bpNum) = (/part(\d+)\.(rom|brom)$/i);
			$bpNum *= 1;
			$bpNum += 1;

			print "Part $bpNum ";

			if($curBNum ne "" && (($bpNum-$curBNum) != 1)){
				++$numWarn;
				print STDERR ":\nWARNING: The build number jumped for part $bpNum in an odd way (it's suppose to do a +1).  The difference in this case is '" . ($bpNum-$curBNum) . "'.\n";
				pause();
			}

			($bdComp, $bdOff, $bdSiz, $bdPOff) = ripROMData("$inDir$_");

			$writeNum = ($bdPOff);
			
			$dirList_temp{$writeNum} = [$_, $bdComp, $bdOff, $bdSiz];

			print " ===> write sequence $writeNum\n";

			$curBNum = $bpNum*1;
		}
		
		@dirListing = map { $dirList_temp{$_} } sort {$a <=> $b} keys(%dirList_temp);

		my $curComp = "";
		my $count = 0;
		$curBNum = "";
		my $isError = 0;
		my $partFile = "";
		my $dlCount = scalar(@dirListing) - 1;
		foreach  (@dirListing) {
			$partFile = shift(@{$_});

			($bpNum) = ($partFile=~/part(\d+)\.(rom|brom)$/i);
			$bpNum *= 1;
			$bpNum += 1;
			$isError = 0;

			print "Part $bpNum ";

			my ($bdComp, $bdOff, $bdSiz, $bdPOff) = @{$_};

			if($curComp ne "" && $curComp != $bdComp){
				++$numWarn;
				$isError = 1;
				print STDERR ":\nWARNING: The build compression changed from '" . compName($curComp) . "' to '" . compName($bdComp) . "' for part $bpNum.  This may be okay.\n";
#				pause();
			}

			$bdUncomSiz = $bdSiz;

			#$outFile = *STDOUT;

			open(FILE, "$inDir$partFile");
				if($bdComp == 0x01 && ($compUse & COMP_LZSS)){
					$bdUncomSiz = decompressLZSSFile($outFile, *FILE, $bdOff, $bdSiz);
				}elsif($bdComp == 0x06 && ($compUse & COMP_ZIP)){
					$bdUncomSiz = inflateFile($outFile, *FILE, $bdOff, $bdSiz);
				}else{
					writeFile($outFile, *FILE, $bdOff, $bdSiz);
				}
			close(FILE);

			if($bdUncomSiz < 0){
				++$numWarn;
				$isError = 1;
				print STDERR ":\nWARNING: The decompression failed for part $bpNum! Defaulting to raw.\n";
				pause();
				writeFile($outFile, *FILE, $bdOff, $bdSiz);
			}

			if(!$isError){
				print "[" . compName($bdComp) . " data at offset $bdOff with size $bdSiz (decompresses to $bdUncomSiz-" . int($bdSiz/$bdUncomSiz*100) . "%)]";
				print "," if($dlCount > $count);
				print "\n";
			}

			$curComp = $bdComp*1;
			++$count;
		}
	closedir(DIR);

	my $finSiz = -s $outFile;
	print "\n\nBuild decompression completed with $numWarn warning(s).  The total size is $finSiz bytes which is ~" . int($finSiz/($count)) . " bytes per part.\n";
	#pause();
}

sub decideFile($){
	my $outFile = shift;

unlink($outFile);
return;

	print "\nThe output file '$outFile' already exists- what should I do?\n\n";
	my @menu = ("Delete old file", "Archive old file", "Exit");

	my $sel = printMenu(0, 1, @menu);

	if($sel == 1){
		unlink($outFile);
	}elsif($sel == 2){
		rename($outFile, "$outFile\_" . time());
	}else{
		exitMe(3);
	}
}

sub compName($) {
	my $comCode = shift;

	if($comCode == 0x01 && ($compUse & COMP_LZSS)){
		return "LZSS";
	}elsif($comCode == 0x06 && ($compUse & COMP_ZIP)){
		return "ZIP";
	}else{
		return "RAW[$comCode]";
	}
	
}

#sub inflateTScript {

#}
#sub deflateTScript {

#}

sub loadCompModules {

	eval('use Compress::Zlib ();');
	if($@){
		print STDERR "ERROR: DEFLATE/RFC1951 (ZIP) compression will be turned off because the 'Compress::Zlib' module is not available for this Perl installation.\n";
		pause();
	}else{
		$compUse |= COMP_ZIP;
	}

#	eval('use Compress::SelfExtracting ();');
#	if($@){
#		print STDERR "ERROR: LZSS compression will be turned off because the 'Compress::SelfExtracting' module is not available for this Perl installation.\n";
#		pause();
#	}else{
		$compUse |= COMP_LZSS;
#	}

	if($compUse == 0){
		print STDERR "ERROR: No compression algorithms available!  Continue using raw extraction? (y/N): "; <>;
		exitMe(2) if(!/^Y/i);
	}
}

sub pause {
	print "Press enter to continue...";
	<>;
}

sub ripROMData($){
	my $openFile = shift;
	
	open(FILE, $openFile);
		my $dataLen = unpack('N', readFile(*FILE, 0x04, 4));
		my $compType = ord(readFile(*FILE, 0x10, 1));
		my $dataStart = unpack('n', readFile(*FILE, 0x1A, 2));
		my $putOffset = unpack('N', readFile(*FILE, 0x14, 4));
	close(FILE);

	return ($compType, $dataStart, $dataLen, $putOffset);
}

sub inflateFile($$$$){
	my $outFile = shift;
	my $FILE = shift;
	my $dataStart = shift;
	my $dataLen = shift;

	my ($d) = Compress::Zlib::inflateInit();
	my ($out, $status) = $d->inflate(readFile(*FILE, $dataStart, $dataLen));
	if($status == 0 || $status == 1){
		
		if(ref($outFile) eq "REF" && (fileno(\$outFile) == fileno(STDOUT))){
			binmode(STDOUT);
			print STDOUT $out;
		}else{
			open(DECOM, ">> $outFile");
				binmode(DECOM);
				print DECOM $out;
			close(DECOM);
		}

		return length($out);
	}else{
		return $status * -1;
	}
}

sub decompressLZSSFile($$$$)
{
	my $outFile = shift;
	my $FILE = shift;
	my $dataStart = shift;
	my $dataLen = shift;

	my $flags = 0;
	my $byte = undef;
	my $byte2 = undef;
	my $data = readFile(*FILE, $dataStart, $dataLen);
	my $out = "";
	my $r = 0;
	my $c = "";
	my $m = "";
	my $j = "";
	for(my $i = 0; $i < length($data); ++$i){
		if(($flags & 0x100) == 0){
			$flags = unpack("C", substr($data, $i, 1)) | 0xFF00;
			++$i;
		}

		($c) = unpack("C", substr($data, $i, 1));
		if(($flags & 1) == 1){
			$out .= chr($c);
		}else{
			$i++;
			my ($jj) = unpack("C", substr($data, $i, 1));

            $m = (($jj & 0xF0) << 4) | $c;
            $j = ($jj & 0x0F) + 3;

			for (my $k = 0; $k < $j; $k++) {
				$out .= substr($out, (length($out) - ($m + 1)), 1);
            }
		}

		$flags >>= 1
	}

	if(ref($outFile) eq "REF" && (fileno(\$outFile) == fileno(STDOUT))){
		binmode(STDOUT);
		print STDOUT $out;
	}else{
		if(open(DECOM, ">> $outFile")){
				binmode(DECOM);
				print DECOM $out;
			close(DECOM);
		}else{
			return -1;
		}
	}

	return length($out);
}


sub writeFile($$$$){
	my $outFile = shift;
	my $FILE = shift;
	my $dataStart = shift;
	my $dataLen = shift;

	if(ref($outFile) && (fileno(\$outFile) == fileno(STDOUT))){
		binmode(STDOUT);
		print STDOUT readFile(*FILE, $dataStart, $dataLen);
	}else{
		if(open(DECOM, ">> $outFile")){
				binmode(DECOM);
				print DECOM readFile(*FILE, $dataStart, $dataLen);
			close(DECOM);
		}else{
			return -1;
		}
	}

}

sub readFile($$$) {
	my $FILE = shift;
	my $rOffset = shift;
	my $rBytes = shift;

	my $buf = "";
	sysseek($FILE, $rOffset, SEEK_SET);
	sysread($FILE, $buf, $rBytes);

	return $buf;
}

__DATA__

  InstallUpgrade
     +0000  80a4c420  27bdffd0	addiu    sp,sp,0xffd0
     +0004  80a4c424  afb3001c	sw       s3,0x1c(sp)
     +0008  80a4c428  00809821	move     s3,a0                                              ; Pointer to build part (s3- arg 0).
     +000c  80a4c42c  3c0480d3	lui      a0,0x80d3
     +0010  80a4c430  24842b10	addiu    a0,a0,0x2b10
     +0014  80a4c434  afb50024	sw       s5,0x24(sp)
     +0018  80a4c438  00a0a821	move     s5,a1
     +001c  80a4c43c  afbf0028	sw       ra,0x28(sp)
     +0020  80a4c440  afb40020	sw       s4,0x20(sp)
     +0024  80a4c444  afb20018	sw       s2,0x18(sp)
     +0028  80a4c448  afb10014	sw       s1,0x14(sp)
     +002c  80a4c44c  afb00010	sw       s0,0x10(sp)
     +0030  80a4c450  8e620014	lw       v0,0x14(s3)
     +0034  80a4c454  3c10bf80	lui      s0,0xbf80                                          ; Bootrom? (dies when s3+0x14 has these bits)
     +0038  80a4c458  00402821	move     a1,v0
     +003c  80a4c45c  0c270de6	jal      0x809c3798 <DoMessage+0>
     +0040  80a4c460  00b03024	and      a2,a1,s0
     +0044  80a4c464  8e620014	lw       v0,0x14(s3)
     +0048  80a4c468  00501024	and      v0,v0,s0
     +004c  80a4c46c  14500003	bne      v0,s0,0x80a4c47c <InstallUpgrade+5c>
     +0050  80a4c470  00009021	move     s2,zero
     +0054  80a4c474  082931b8	j        0x80a4c6e0 <InstallUpgrade+2c0>
     +0058  80a4c478  24020004	li       v0,0x4
     +005c  80a4c47c  9662001a	lhu      v0,0x1a(s3)                                        ; Data offset s3+0x1A (WORD)
     +0060  80a4c480  0000a021	move     s4,zero
     +0064  80a4c484  02628821	addu     s1,s3,v0                                           ; -Data pointer in s1-
     +0068  80a4c488  92620010	lbu      v0,0x10(s3)
     +006c  80a4c48c  1040002d	beq      v0,zero,0x80a4c544 <InstallUpgrade+124>            ; If comp type = 0 then data is raw
     +0070  80a4c490  8e700008	lw       s0,0x8(s3)
     +0074  80a4c494  0c28093b	jal      0x80a024ec <AllocateMemorySystemNilAllowed+0>
     +0078  80a4c498  02002021	move     a0,s0
     +007c  80a4c49c  0040a021	move     s4,v0
     +0080  80a4c4a0  12800026	beq      s4,zero,0x80a4c53c <InstallUpgrade+11c>
     +0084  80a4c4a4  24020001	li       v0,0x1 ;-
     +0088  80a4c4a8  92630010	lbu      v1,0x10(s3)                                        ; Compression type offset (s3+0x10 byte).
     +008c  80a4c4ac  10620005	beq      v1,v0,0x80a4c4c4 <InstallUpgrade+a4>               ; Build is LZSS compressed. v0 = 0x01
     +0090  80a4c4b0  24020006	li       v0,0x6 ;-
     +0094  80a4c4b4  5062000e	beql     v1,v0,0x80a4c4f0 <InstallUpgrade+d0>               ; Build is ZIP compressed. v0 = 0x06
     +0098  80a4c4b8  3c0480d3	lui      a0,0x80d3
     +009c  80a4c4bc  08293148	j        0x80a4c520 <InstallUpgrade+100>                    ; Unkown compression- give up.
     +00a0  80a4c4c0  3c0480d3	lui      a0,0x80d3
; ----------------------------------------------
; ------------------------------------------ LZSS
; ----------------------------------------------
	 +00a4  80a4c4c4  3c0480d3	lui      a0,0x80d3
     +00a8  80a4c4c8  0c270de6	jal      0x809c3798 <DoMessage+0>
     +00ac  80a4c4cc  24842b34	addiu    a0,a0,0x2b34
     +00b0  80a4c4d0  02202021	move     a0,s1                                              ; Data
     +00b4  80a4c4d4  02802821	move     a1,s4
     +00b8  80a4c4d8  8e660004	lw       a2,0x4(s3)                                         ; Data len s3+0x04 (DWORD)
     +00bc  80a4c4dc  02003821	move     a3,s0
     +00c0  80a4c4e0  0c270324	jal      0x809c0c90 <ExpandLzss+0>
     +00c4  80a4c4e4  02808821	move     s1,s4                                              ; Decompressed data
     +00c8  80a4c4e8  08293152	j        0x80a4c548 <InstallUpgrade+128>
     +00cc  80a4c4ec  02602021	move     a0,s3                                              ; Same as +0124 but we skip that here.
; ----------------------------------------------
; ------------------------------------------ ZIP
; ----------------------------------------------
	 +00d0  80a4c4f0  0c270de6	jal      0x809c3798 <DoMessage+0>
     +00d4  80a4c4f4  24842b4c	addiu    a0,a0,0x2b4c
     +00d8  80a4c4f8  26240002	addiu    a0,s1,0x2                                          ; Data+0x02
     +00dc  80a4c4fc  02802821	move     a1,s4
     +00e0  80a4c500  8e660004	lw       a2,0x4(s3)                                         ; Data len s3+0x04 (DWORD)
     +00e4  80a4c504  02003821	move     a3,s0
     +00e8  80a4c508  0c298f2e	jal      0x80a63cb8 <ExpandZip+0>
     +00ec  80a4c50c  24c6fffe	addiu    a2,a2,0xfffe
     +00f0  80a4c510  1040000c	beq      v0,zero,0x80a4c544 <InstallUpgrade+124>
     +00f4  80a4c514  02808821	move     s1,s4                                              ; Decompressed data
     +00f8  80a4c518  082931a7	j        0x80a4c69c <InstallUpgrade+27c>                    ; Error - die
     +00fc  80a4c51c  24120001	li       s2,0x1
; ----------------------------------------------
; ------------------------------------------ DIE
; ----------------------------------------------
     +0100  80a4c520  0c270de6	jal      0x809c3798 <DoMessage+0>
     +0104  80a4c524  24842b64	addiu    a0,a0,0x2b64
     +0108  80a4c528  02802021	move     a0,s4
	 +010c  80a4c52c  0c280b5d	jal      0x80a02d74 <FreeMemory+0>
     +0110  80a4c530  00002821	move     a1,zero
     +0114  80a4c534  082931b8	j        0x80a4c6e0 <InstallUpgrade+2c0>
     +0118  80a4c538  24020001	li       v0,0x1
     +011c  80a4c53c  082931b8	j        0x80a4c6e0 <InstallUpgrade+2c0>
     +0120  80a4c540  24020005	li       v0,0x5
; ----------------------------------------------
; ----------------------------------------------
     +0124  80a4c544  02602021	move     a0,s3 
     +0128  80a4c548  02202821	move     a1,s1
     +012c  80a4c54c  0c2931c1	jal      0x80a4c704 <AuthenticateUpgradeSignature+0>
     +0130  80a4c550  02003021	move     a2,s0
     +0134  80a4c554  14400006	bne      v0,zero,0x80a4c570 <InstallUpgrade+150>
     +0138  80a4c558  3c028000	lui      v0,0x8000
     +013c  80a4c55c  3c0480d3	lui      a0,0x80d3
     +0140  80a4c560  0c270de6	jal      0x809c3798 <DoMessage+0>
     +0144  80a4c564  24842b90	addiu    a0,a0,0x2b90
     +0148  80a4c568  082931a7	j        0x80a4c69c <InstallUpgrade+27c>
     +014c  80a4c56c  24120003	li       s2,0x3
     +0150  80a4c570  8c425db0	lw       v0,0x5db0(v0)
     +0154  80a4c574  1040002c	beq      v0,zero,0x80a4c628 <InstallUpgrade+208>
     +0158  80a4c578  3c038000	lui      v1,0x8000
     +015c  80a4c57c  8c625db4	lw       v0,0x5db4(v1)
     +0160  80a4c580  10400003	beq      v0,zero,0x80a4c590 <InstallUpgrade+170>
     +0164  80a4c584  3c02800a	lui      v0,0x800a
     +0168  80a4c588  08293165	j        0x80a4c594 <InstallUpgrade+174>
     +016c  80a4c58c  8c42fe40	lw       v0,0xfffffe40(v0)
     +0170  80a4c590  00001021	move     v0,zero
     +0174  80a4c594  10400024	beq      v0,zero,0x80a4c628 <InstallUpgrade+208>
     +0178  80a4c598  8c625db4	lw       v0,0x5db4(v1)
     +017c  80a4c59c  10400003	beq      v0,zero,0x80a4c5ac <InstallUpgrade+18c>
     +0180  80a4c5a0  3c02800a	lui      v0,0x800a
     +0184  80a4c5a4  0829316c	j        0x80a4c5b0 <InstallUpgrade+190>
     +0188  80a4c5a8  8c44fe40	lw       a0,0xfffffe40(v0)
     +018c  80a4c5ac  00002021	move     a0,zero
     +0190  80a4c5b0  8c820010	lw       v0,0x10(a0)
     +0194  80a4c5b4  8c420030	lw       v0,0x30(v0)
     +0198  80a4c5b8  0040f809	jalr     ra,v0
     +019c  80a4c5bc  00000000	nop      
     +01a0  80a4c5c0  8c420080	lw       v0,0x80(v0)
     +01a4  80a4c5c4  30420004	andi     v0,v0,0x4
     +01a8  80a4c5c8  14400018	bne      v0,zero,0x80a4c62c <InstallUpgrade+20c>
     +01ac  80a4c5cc  02202021	move     a0,s1
     +01b0  80a4c5d0  3c128000	lui      s2,0x8000
     +01b4  80a4c5d4  8e425ba0	lw       v0,0x5ba0(s2)
     +01b8  80a4c5d8  1440000e	bne      v0,zero,0x80a4c614 <InstallUpgrade+1f4>
     +01bc  80a4c5dc  8e445ba0	lw       a0,0x5ba0(s2)
     +01c0  80a4c5e0  0c280730	jal      0x80a01cc0 <__builtin_new+0>
     +01c4  80a4c5e4  24040018	li       a0,0x18
     +01c8  80a4c5e8  00408021	move     s0,v0
     +01cc  80a4c5ec  0c292a7a	jal      0x80a4a9e8 <PriorityList::PriorityList+0>
     +01d0  80a4c5f0  02002021	move     a0,s0
     +01d4  80a4c5f4  ae000010	sw       zero,0x10(s0)
     +01d8  80a4c5f8  ae000014	sw       zero,0x14(s0)
     +01dc  80a4c5fc  16000004	bne      s0,zero,0x80a4c610 <InstallUpgrade+1f0>
     +01e0  80a4c600  ae505ba0	sw       s0,0x5ba0(s2)
     +01e4  80a4c604  3c0480d3	lui      a0,0x80d3
     +01e8  80a4c608  0c270dbb	jal      0x809c36ec <DoAssert+0>
     +01ec  80a4c60c  24842bcc	addiu    a0,a0,0x2bcc
     +01f0  80a4c610  8e445ba0	lw       a0,0x5ba0(s2)
     +01f4  80a4c614  02602821	move     a1,s3
     +01f8  80a4c618  0c293315	jal      0x80a4cc54 <UpgradeRAMCache::AddBlock+0>
^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v
  UpgradeRAMCache::AddBlock
     +003c  80a4cc90  8e430014	lw       v1,0x14(s2)                                                 ; Offset to decompress this block (s2[same as s3 in InstallUpgrade]+0x14 DWORD)
^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v
     +01fc  80a4c61c  02203021	move     a2,s1
     +0200  80a4c620  08293190	j        0x80a4c640 <InstallUpgrade+220>
     +0204  80a4c624  00409021	move     s2,v0
     +0208  80a4c628  02202021	move     a0,s1
     +020c  80a4c62c  8e650014	lw       a1,0x14(s3)
     +0210  80a4c630  0c266392	jal      0x80998e48 <WriteBrowserStorage+0>
     +0214  80a4c634  02003021	move     a2,s0
     +0218  80a4c638  54400001	bnel     v0,zero,0x80a4c640 <InstallUpgrade+220>
     +021c  80a4c63c  24120002	li       s2,0x2
     +0220  80a4c640  12a00016	beq      s5,zero,0x80a4c69c <InstallUpgrade+27c>
     +0224  80a4c644  00000000	nop      
     +0228  80a4c648  16400014	bne      s2,zero,0x80a4c69c <InstallUpgrade+27c>
     +022c  80a4c64c  3c108000	lui      s0,0x8000
     +0230  80a4c650  8e045ba0	lw       a0,0x5ba0(s0)
     +0234  80a4c654  10800009	beq      a0,zero,0x80a4c67c <InstallUpgrade+25c>
     +0238  80a4c658  00000000	nop      
     +023c  80a4c65c  0c293379	jal      0x80a4cde4 <UpgradeRAMCache::FlushToDisk+0>
     +0240  80a4c660  00000000	nop      
     +0244  80a4c664  8e045ba0	lw       a0,0x5ba0(s0)
     +0248  80a4c668  10800003	beq      a0,zero,0x80a4c678 <InstallUpgrade+258>
     +024c  80a4c66c  00409021	move     s2,v0
     +0250  80a4c670  0c2932f4	jal      0x80a4cbd0 <UpgradeRAMCache::~UpgradeRAMCache+0>
     +0254  80a4c674  24050003	li       a1,0x3
     +0258  80a4c678  ae005ba0	sw       zero,0x5ba0(s0)
     +025c  80a4c67c  16400007	bne      s2,zero,0x80a4c69c <InstallUpgrade+27c>
     +0260  80a4c680  00000000	nop      
     +0264  80a4c684  0c266444	jal      0x80999110 <ToggleBrowserSelect+0>
     +0268  80a4c688  00000000	nop      
     +026c  80a4c68c  0c266432	jal      0x809990c8 <GetBrowserSelect+0>
     +0270  80a4c690  00408021	move     s0,v0
     +0274  80a4c694  54500001	bnel     v0,s0,0x80a4c69c <InstallUpgrade+27c>
     +0278  80a4c698  24120006	li       s2,0x6
; ----------------------------------------------
; ----------------------------------------------
	 +027c  80a4c69c  12800003	beq      s4,zero,0x80a4c6ac <InstallUpgrade+28c>
     +0280  80a4c6a0  02802021	move     a0,s4
     +0284  80a4c6a4  0c280b5d	jal      0x80a02d74 <FreeMemory+0>
     +0288  80a4c6a8  00002821	move     a1,zero
     +028c  80a4c6ac  3c0480d3	lui      a0,0x80d3
     +0290  80a4c6b0  24842bd8	addiu    a0,a0,0x2bd8
     +0294  80a4c6b4  0c270de6	jal      0x809c3798 <DoMessage+0>
     +0298  80a4c6b8  02402821	move     a1,s2
     +029c  80a4c6bc  12400007	beq      s2,zero,0x80a4c6dc <InstallUpgrade+2bc>
     +02a0  80a4c6c0  3c108000	lui      s0,0x8000
     +02a4  80a4c6c4  8e045ba0	lw       a0,0x5ba0(s0)
     +02a8  80a4c6c8  10800005	beq      a0,zero,0x80a4c6e0 <InstallUpgrade+2c0>
     +02ac  80a4c6cc  02401021	move     v0,s2
     +02b0  80a4c6d0  0c2932f4	jal      0x80a4cbd0 <UpgradeRAMCache::~UpgradeRAMCache+0>
     +02b4  80a4c6d4  24050003	li       a1,0x3
     +02b8  80a4c6d8  ae005ba0	sw       zero,0x5ba0(s0)
     +02bc  80a4c6dc  02401021	move     v0,s2
; ----------------------------------------------
; ----------------------------------------------
     +02c0  80a4c6e0  8fbf0028	lw       ra,0x28(sp)
     +02c4  80a4c6e4  8fb50024	lw       s5,0x24(sp)
     +02c8  80a4c6e8  8fb40020	lw       s4,0x20(sp)
     +02cc  80a4c6ec  8fb3001c	lw       s3,0x1c(sp)
     +02d0  80a4c6f0  8fb20018	lw       s2,0x18(sp)
     +02d4  80a4c6f4  8fb10014	lw       s1,0x14(sp)
     +02d8  80a4c6f8  8fb00010	lw       s0,0x10(sp)
     +02dc  80a4c6fc  03e00008	jr       ra
     +02e0  80a4c700  27bd0030	addiu    sp,sp,0x30