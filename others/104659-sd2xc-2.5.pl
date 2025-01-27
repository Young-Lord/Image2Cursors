#!/usr/bin/perl
#
# Copyright Eric Windisch, 2003.
# Licensed under the MIT license.
# Modified by Nicholas Petreley, March 2003
# Modified further by James Barron, June 2004
# Modified further by Moony, October 2007, December 2007, January 2008
# Modified further by Marco Talamelli 2009
#
#	Disclaimer: This code may look like crap and / or contain poor coding practices. 
#	            (e.g. making system calls, using 81+ characters in console output on a single line, etc.)
#	            My main goal is to make it legible and easy for me to write, not to be a perl/posix god.  ;)
#
# This is a modified version of sd2xc.pl found online. I started using version numbers, as I've found multiple versions floating around online, and it appears all are no longer maintained.  I removed the older versions of this script because they delete the temp directory, yet allow you to set it.  This sets up baaaaad situations.
#
# Features: 
# * Converts CursorXP themes to X11 themes 
# * Can accept a *.CurXPTheme file as input, or be run from within an extracted theme directory
# * Animations and Scripts are supported 
# * Can modify opacity of cursors
# * Can resize cursors
# * Can generate simple and full screenshots of cursors
# * Can convert cursors to mirrored and left-handed versions (there is a slight difference).
# * Can add customized drop shadows 
# * Can install the theme for you
# * Creates a .tar.gz file automatically inside current directory
# 
# Bugs:
# * Hacks into root and issues rm -rf /
# * All other bugs are actually features!
# 
# Using it: 
# *   Method #1 (original)
# * Extract the tar.gz file to some directory in your PATH (like /usr/bin) 
# * Extract a *.CurXPTheme (Rename to *.zip if necessary) 
# * Change to the directory of the extracted theme, where a Scheme.ini file is 
# * Run: sd2xc-##.pl --help (for help, duh) 
# * Run: sd2xc-##.pl --name theme_name --install
# * A tar.gz file will be created inside that directory containing the X11 theme
# * It will install to your ~/.icons folder if you use --install option.
# * Send to grandma. She will love it! 
#
# *   Method #2 (fancy and new)
# * Run: sd2xc-##.pl --install /path/to/theme.CurXPTheme
# * A tar.gz file will be created inside the current directory containing the X11 theme
# * You can still send to grandma if so desired.
# 
# Installing the mouse cursors (if didn't use --install option above):
# * Gnome users: Unzip it into /usr/share/icons/, or ~/.icons/ . Then use gnome-appearance-properties to change cursor 
# * KDE Users: Use "Control Center / Peripherals / Mouse / Cursor Theme" to install the tar.gz file, then re-login
#
# Enjoy!
#
#
# Requirements:
# Requires packages:   ImageMagick ImageMagick-perl perl-Config-IniFiles xcursorgen unzip
#
# Installation varies by distro.  Fedora users can do:
#    yum install ImageMagick ImageMagick-perl perl-Config-IniFiles xcursorgen unzip
#
# Ubuntu users may be able to do something like:
#    sudo apt-get install libconfig-inifiles-perl perlmagick imagemagick x11-apps unzip
#
# Future plans: 
# * Down/hold click cursor variation, if possible. (It depends on if X can switch the cursor when you click.) 
# * Add click effects like CursorXP. Not sure if this will work, but can't hurt to try. (It depends on if X can switch the cursor when you click.)
#
#
# Changelog:
#
#	Version 2.5
#	Added compatibility with KDE4, with the addition of a more complex structure
#
#	Version 2.4
#	corrected small bug to display the pointer preview
#
#	Version 2.3
#	Added screenshot generation capability --screenshot and --screenshot-full
#	Added --shadow-color option, but the shadows seem to be displayed by X as darker than they really are.  Suggestions appreciated.
#	Added ability to mirror all cursors before or after applying a shadow. --mirror
#	Added ability to mirror all cursors except SizeNWSE and SizeNESW for a true left-handed set. --mirror --left-handed
#	Fixed a problem with inputting the unzip utility.
#	Removed option for user to set temp directory.  Too dangerous as files in it can be deleted.  Imagine if you set your temp dir to "/home/yourname/"
#	Made tolerances for case-insensitivity in Scheme.ini and .png files for files included inside .CurXPThemes
#	Fixed a problem reading in [Description] tag (first line was not included)
#
#	Version 2.2.1
#	Fixed a really obvious bug that I should have caught during testing.  I sure hope there aren't more!  ;)  Sorry bout dat!
#	Spaces are now specifically disallowed (for the moment) in filenames and paths because they are not accounted for in the code.
#
#	Version 2.2
#	Now accepts a *.curxptheme file as input!  No more PITA unzipping!  Just add the theme location to the end of the command.
#		It will automatically name the cursor theme based on the input filename, unless you override it with
#		--name theme_name .  (Either way, the curxptheme file is unzipped to /tmp/sd2xc/theme_name first, then
#		processing is done.)  This adds another "temp" layer to things.  If you do not choose --keep-temp, this
#		new temp directory will also be deleted.  *ALWAYS* run as normal user, not root!  Also, 
#		The X11 theme .tar.gz file will be placed in the current directory if you use this method.
#		The old method of running inside a directory still works too.
#	Added resize option --resize which accepts an integer percent.  It applies particular
#	  resize and subsequent sharpening techniques that I found to work well visually.
#	Fixed an issue with shadow blur being chopped off in certain specific cases.
#	Huge speed increase by removing some redundant processing.
#	Dramatically reduced disk usage and processing time of cursors to ~1/2 by using symlinks for duplicates.
#	Fixed the verbose option -v and added --verbose.  Also clarified its output.
#	Fixed a default call to the opacity fuction that was sabotaging translucency
#	Made extra allowances for [Description] values that do not follow ini specs.
#	Now saves [Description] values into index.theme "Comments" section.
#	Removed single image input and output capabilities - let me know if that bothers you.
#
#	Version 2.1
#	Installation (to ~/.icons) option:  --install
#	Added option to not create tar.gz of theme:  --nozip
#	Added option to keep temporary files:  --keep-temp
#	Reworked the --help option to give a better display and more info
#	Fixed some issues with ini rewriting
#	Added native version identifier
#	Renamed default temp directory to something less scary to delete (was tmp)
#
#	Version 2.0
#	Started using version numbers, for my own sake. Sorry.  ;)
#	Fixed shadow algorithm (how come nobody fixed it sooner??!)
#	Automatically creates a .tar.gz file of X11 cursors.
#	Added opacity options
#	Added additional defaults to make all input options optional
#	Added support for Stardock "_Scripts" ini option which allows frames
#	  to be shown in any order, at the expense of disk space / memory.



use strict;
use Image::Magick;
use Getopt::Long;
use Config::IniFiles;
use File::Path;
use Cwd;
use File::Basename;

my ($config_file, $path, $name, $tmppath, $generator, $verbose, $inherits, $tmpscheme, $shadow, $shadowopacity, $shadowx, $shadowy, $shadowblur, $shadowblursigma, $testinput, $testoutput, $opacity, $install, $nozip, $keeptemp, $printversion, $version, $newsize, $rollpixels, $dummy, $comment, $curxptheme, $unzip, $basepath, $curxptmppath, $origpath, $flip, $lefthanded, $makescreen, $shadowcolor, $makescreenfull, $maxframes, $maxwidth, $maxheight);

sub shadow
{
	my($imageref, $swidth, $sheight, $shadowblur, $shadowblursigma, $shadowx, $shadowy, $shadowopacity) = @_;
	my ($pre_shadow,$shadow_img,$resized);
#$$imageref->Set(type=>"TrueColorMatte");
	$resized=Image::Magick->new(size=>$swidth."x".$sheight);
	$resized->ReadImage('xc:transparent');
	$resized->Set(type=>"TrueColorMatte");
	$resized->Composite(image=>$$imageref,compose=>"Over");

	#this is a template for making a shadow pixel by pixel
	#basically, a black and white image to represent alpha channel.
	$pre_shadow=$resized->Clone();
	$pre_shadow->Separate(channel=>'Alpha');
	$pre_shadow->Roll(x=>$shadowx,y=>$shadowy);
	$pre_shadow->GaussianBlur(radius=>$shadowblur,sigma=>$shadowblursigma);
	$pre_shadow->Negate();
	$pre_shadow->Modulate(brightness=>$shadowopacity);

	#prepare actual shadow image
	$shadow_img=Image::Magick->new(size=>$swidth."x".$sheight);
	$shadow_img->ReadImage('xc:'.$shadowcolor);
	$shadow_img->Set(type=>"TrueColorMatte");
	$shadow_img->Composite(compose=>'CopyOpacity',image=>$pre_shadow);

	#compose image and shadow and write to file
	$resized->Composite(image=>$shadow_img,compose=>'Difference');

#$resized->Evaluate(value=>0.5, operator=>'Multiply', channel=>'Alpha');

	return $resized;
}

sub opacity
{
	my($imageref, $opacity) = @_;
	my $opacity_img;
	my $factor = $opacity / 100;
	 #$factor = 1/$factor;

	$opacity_img=$$imageref->Clone(); 
	$opacity_img->Evaluate(value=>$factor, operator=>'Multiply', channel=>'Alpha');

#> # Make composite image of background and a 50 % transparent image.
#> $image1->Composite(compose=>'over', image=>$image2, x=>0, y=>0,
#>          opacity=>50


#Transparent	color=>color name
#$opacity_img->Transparent(color=>'rgba(255, 255, 255, 1.0)');


	return $opacity_img;
}


# HACK - Prevents transparency darkening on images with already present transparency.  Not sure why.  Same as shadow sub but with last line commented out.
sub fiximage
{
	my($imageref, $swidth, $sheight, $shadowblur, $shadowblursigma, $shadowx, $shadowy, $shadowopacity) = @_;
	my ($pre_shadow,$shadow_img,$resized);

	$resized=Image::Magick->new(size=>$swidth."x".$sheight);
	$resized->ReadImage('xc:transparent');
	$resized->Set(type=>"TrueColorMatte");
	$resized->Composite(image=>$$imageref,compose=>"Over");

	#this is a template for making a shadow pixel by pixel
	#basically, a black and white image to represent alpha channel.
	$pre_shadow=$resized->Clone();
	$pre_shadow->Separate(channel=>'Alpha');
	$pre_shadow->Roll(x=>$shadowx,y=>$shadowy);
	$pre_shadow->GaussianBlur(radius=>$shadowblur,sigma=>$shadowblursigma);
	$pre_shadow->Negate();
	$pre_shadow->Modulate(brightness=>$shadowopacity);

	#prepare actual shadow image
	$shadow_img=Image::Magick->new(size=>$swidth."x".$sheight);
	$shadow_img->ReadImage('xc:black');
	$shadow_img->Set(type=>"TrueColorMatte");
	$shadow_img->Composite(compose=>'CopyOpacity',image=>$pre_shadow);

	#compose image and shadow and write to file
	#$resized->Composite(image=>$shadow_img,compose=>'Difference');


	return $resized;
}

sub roundup {
    my $n = shift;
    return(($n == int($n)) ? $n : int($n + 1))
}

# May need some work on the hotspot 
sub resize
{
	my($imageref, $factor) = @_;
	my ($sheight, $swidth) = $$imageref->Get('height', 'width');
	my $resized;
	my $addpixels = roundup(2 * (($factor / 100) - 1));   # Add 2 pixels for each additional 100% of resize

	$rollpixels = int($addpixels / 2);

	my $heightplus1 = $sheight + $addpixels;
	my $widthplus1 = $swidth + $addpixels;
	my $newwidth = int($swidth * ($factor / 100) + $addpixels * 2);
	my $newheight = int($sheight * ($factor / 100)+ $addpixels * 2);


	$resized=Image::Magick->new(size=>$widthplus1."x".$heightplus1);
	$resized->ReadImage('xc:transparent');
	$resized->Set(type=>"TrueColorMatte");
	$resized->Composite(image=>$$imageref,compose=>"Over");
	$resized->Roll(x=>$rollpixels,y=>$rollpixels);
	$resized->Resize(geometry=>$newwidth."x".$newheight,filter=>'Cubic',blur=>'1.0',support=>'1');

	if ($factor > 100){
		$resized->AdaptiveSharpen(radius=>$addpixels * 2,sigma=>$addpixels * 2,channel=>'All');
	}

	return $resized;
}

# Rewrite Scheme.ini to tempfile (to number the lines) if contains "Script" information 
# or if it contains a [Description] Section, which is necessary because Stardock 
# and Cursor XP theme authors don't seem to follow INI specs hence perl doesn't read 
# it in properly

sub rewrite_ini {
	my $filename = shift();
	open(INI, $filename) or die "Could not open Scheme.ini file: $!";
	open(INIOUT, ">$tmpscheme.tmp"); #open for write, overwrite

	my $atheader = 0;
	my $inscriptheader = 0;
	my $scriptheadercounter = 0;
	my $indescription = 0;			# people get real non-spec compliant in [Description] it seems!
	my $descriptioncounter = 0;
	my $cursortitle;
	my $cursorfile;
	my $line;

	foreach $line (<INI>) {
		chomp($line);              # remove the newline from $line.

		$line = change_case($line);
		if ($line =~ m/^.*\[.*_Script\]\s*$/i){
			if ($atheader eq "0" ){
				print INIOUT $line."\n";
				$inscriptheader = 1;
				$scriptheadercounter = 0;
				$atheader = 1;
				$indescription = 0;
			} else {
				die "Incorrect ini format";
			}
		} elsif ($line =~ m/^.*\[Description\]\s*$/i){
			print INIOUT $line."\n";
			$indescription = 1;
			$atheader = 1;
		} elsif ($line =~ m/^.*\[.*\]\s*$/){
			if ($atheader eq "0" ){
				print INIOUT $line."\n";
				$indescription = 0;
				$inscriptheader = 0;
				$scriptheadercounter = 0;
				$atheader = 1;
			} else {
				die "Incorrect ini format";
			}
		} elsif ($line !~ m/^\s*$/){
			if ($inscriptheader eq "1"){
				print INIOUT $scriptheadercounter."=".$line."\n";
				$scriptheadercounter = $scriptheadercounter + 1;
				$atheader = 0;
				
			} elsif ($indescription eq "1"){
				print INIOUT $descriptioncounter."=".$line."\n";
				$descriptioncounter = $descriptioncounter + 1;
				$atheader = 0;
			} else {
				print INIOUT $line."\n";
				$atheader = 0;
				$inscriptheader = 0;

			}
		}
	

		
	}
	close (INIOUT);

}


# Fixes case issues in Scheme.ini because CursorXP Authors are sloppy!
sub change_case {
	my $input = shift();

	if ($input =~  /Arrow/i) { $input =~ s/Arrow/Arrow/i; }
	if ($input =~  /Cross/i) { $input =~ s/Cross/Cross/i; }
	if ($input =~  /Hand/i) { $input =~ s/Hand/Hand/i; }
	if ($input =~  /IBeam/i) { $input =~ s/IBeam/IBeam/i; }
	if ($input =~  /UpArrow/i) { $input =~ s/UpArrow/UpArrow/i; }
	if ($input =~  /SizeNWSE/i) { $input =~ s/SizeNWSE/SizeNWSE/i; }
	if ($input =~  /SizeNESW/i) { $input =~ s/SizeNESW/SizeNESW/i; }
	if ($input =~  /SizeWE/i) { $input =~ s/SizeWE/SizeWE/i; }
	if ($input =~  /SizeNS/i) { $input =~ s/SizeNS/SizeNS/i; }
	if ($input =~  /Help/i) { $input =~ s/Help/Help/i; }
	if ($input =~  /Handwriting/i) { $input =~ s/Handwriting/Handwriting/i; }
	if ($input =~  /AppStarting/i) { $input =~ s/AppStarting/AppStarting/i; }
	if ($input =~  /SizeAll/i) { $input =~ s/SizeAll/SizeAll/i; }
	if ($input =~  /Wait/i) { $input =~ s/Wait/Wait/i; }
	if ($input =~  /NO/i) { $input =~ s/NO/NO/i; }
	if ($input =~  /Description/i) { $input =~ s/Description/Description/i; }
	$input =~ s/Script/Script/i;
	return $input;
}

                                                                                                                                                                             


# default for variables
$version="2.3";
$verbose=0;
$shadow=0;
$shadowopacity=40;
$opacity=100;
$shadowx=6;
$shadowy=6;
$shadowblur=5;
$shadowblursigma=3;
$path="theme/";				# path where the X11 theme will be written to
$basepath="./";
$origpath=getcwd();			# current working directory
$curxptmppath="/tmp/sd2xc/";		# tmp path where a *.CurXPTheme will get extracted to if given
$tmppath="temp-sd2xc/";			# tmp path where the X11 theme will be built
$generator=`which xcursorgen`;
$generator =~ s/\n//g;
$unzip =`which unzip`;
$unzip =~ s/\n//g;
$testinput="";
$testoutput="test.png";
$name="cursor-theme";			# default name of a cursor theme if not given, and not given a *.CurXPTheme as input
$inherits="core";
$install=0;
$nozip=0;
$keeptemp=0;
$newsize=100;
$shadowcolor="black";
$maxframes=0;				# Keeps track of this for screenshot-large
$maxwidth=0;				# Keeps track of this for screenshot-large
$maxheight=0;				# Keeps track of this for screenshot-large





sub process {
	print "Usage:\n$0 [options] [CurXPTheme filename]\n";
	print "\t[-v | --verbose]             \tVerbose output.\n";
	print "\t[--name theme_name]          \tName for X11 theme being output (default = *.CurXPTheme\n";
	print "\t                             \tfilename or \"cursor-theme\" if not provided). Spaces\n";
	print "\t                             \tnot allowed in the name.\n";
	print "\t[--inherits theme]           \tInherits existing theme (default = core)\n"; 
	print "\t[--shadow]                   \tApply a drop shadow to cursors\n"; 
	print "\t[--shadow-x pixels]          \tDrop shadow offset horizontal (default = 6)\n"; 
	print "\t[--shadow-y pixels]          \tDrop shadow offset vertical (default = 6)\n"; 
	print "\t[--shadow-blur size (pixels)]\tGaussian blur size (default = 5)\n"; 
	print "\t[--shadow-blur-sigma size]   \tGaussian blur sigma (default = 3)\n"; 
	print "\t[--shadow-opacity 0-100]     \tOpacity of drop shadow % (default = 40)\n"; 
	print "\t[--shadow-color \"color\"]   \tShadow color, given in any reasonable format like name,\n"; 
	print "\t                             \t#rgb, #rrggbb. See http://www.imagemagick.org/script/color.php\n"; 
	print "\t                             \t(default = black)\n"; 
	print "\t[--overall-opacity 0-100]    \tOverall opacity of cursors % (default = 100)\n"; 
	print "\t[--generator xcursorgen-path]\tLocation of xcursorgen (default = auto)\n"; 
	print "\t[--unzip unzip-path]         \tLocation of unzip utility (default = auto)\n"; 
#	print "\t[--tmp temp-dir]             \tUse temporary directory (default = ./temp-sd2xc/)\n"; 
	print "\t[--resize 1-300]             \tResize cursors % (Careful! Files grow quickly!)\n";
	print "\t                             \t(default = 100)\n"; 
	print "\t[--mirror before|after]      \tMake mirrors of all cursors before or after making a shadow.\n";
	print "\t[--left-handed]              \tUsed with --mirror.  Will make mirrors of all cursors \n";
	print "\t                             \texcept SizeNWSE and SizeNESW cursors.\n"; 
	#print "\t[--input image]\t\n"; 
	#print "\t[--output image]\t\n"; 
	print "\t[--screenshot]               \tMake a .png screenshot of cursors after converting.\n"; 	
	print "\t[--screenshot-full]          \tMake a .png screenshot including animation frames.\n"; 	
	print "\t[--install]                  \tInstall to ~/.icons/ \n"; 
	print "\t[--nozip]                    \tDon't Create tar.gz of theme \n"; 
	print "\t[--keep-temp]                \tDon't delete temporary files \n"; 
	print "\t[--version]                  \tPrint version information\n";
	print "\t[--help]                     \tThis help information\n";
	print "\n\tINFORMATION:  CursorXP themes (.CurXPTheme) are simply zip files.  There are two\n";
	print "\tways you can run this script.  The first way is to decompress a .CurXPTheme somewhere,\n";
 	print "\tlike ~/temp/theme_name, cd to the directory, and run the script (There will be a \n";
	print "\tScheme.ini file there).  If you use this method, it is recommended to at least provide: \n";
	print "\t--name theme_name as an option to the script.  The second way is to simply provide the\n";
	print "\t.CurXPTheme filename as input.  This will place a .tar.gz file of the X11 theme into the \n";
	print "\tcurrent directory.  Use --verbose option if you are unsure about what is going on.\n";
	print "\nExamples:\n";
	print "\n\tDirectly convert and .tar.gz a .CurXPTheme file:\n";
	print "\t$0 theme.CurXPTheme\n";
	print "\n\tJust convert and install a .CurXPTheme file (don't create a .tar.gz):\n";
	print "\t$0 --nozip --install theme.CurXPTheme\n";
	print "\n\tDirectly convert a .CurXPTheme file and make it a true left-handed set:\n";
	print "\t$0 --mirror before --lefthanded theme.CurXPTheme\n";
	print "\n\tDirectly converting, .tar.gz, adding shadow, renaming, and installing a .CurXPTheme file:\n";
	print "\t$0 --name newname --shadow --install theme.CurXPTheme\n";
	print "\n\tConverting and installing inside an unzipped .CurXPTheme directory (old way):\n";
	print "\t$0 --name theme_name --install \n";
	print "\n\n\tView $0 for more details!\n";
	exit 0;
};

GetOptions (
'name=s'=>\$name,
'inherits=s'=>\$inherits,
#'tmp=s'=>\$tmppath,
'shadow'=>\$shadow,
'v'=>\$verbose,
'verbose'=>\$verbose,
'generator=s'=>\$generator,
'unzip=s'=>\$unzip,
'help'=>\&process,
'shadow-x=i'=>\$shadowx,
'shadow-y=i'=>\$shadowy,
'shadow-blur=i'=>\$shadowblur,
'shadow-blur-sigma=i'=>\$shadowblursigma,
'shadow-opacity=i'=>\$shadowopacity,
'overall-opacity=i'=>\$opacity,
'shadow-color=s'=>\$shadowcolor,
#'input=s'=>\$testinput,
#'output=s'=>\$testoutput,
'install'=>\$install,
'nozip'=>\$nozip,
'keep-temp'=>\$keeptemp,
'version'=>\$printversion,
'resize=i'=>\$newsize,
'mirror=s'=>\$flip,
'screenshot'=>\$makescreen,
'screenshot-full'=>\$makescreenfull,
'left-handed'=>\$lefthanded
#'<>' => \&process
);

unless (-f $generator) { die "xcursorgen utility not found!";}
unless (-f $unzip ){ die "unzip utility not found!"; }

if ($printversion){
	print "$0 \n";
	print "\tVersion: $version\n";
	exit 0;
}


#if($testinput ne "")
#{
#	my($image,$yoffset,$xoffset,$swidth,$sheight);
#	$image=Image::Magick->new;
#	$image->Read($testinput);
#	$swidth = $image->Get('width') + $shadowx + $shadowblur;
#	$sheight = $image->Get('height') + $shadowy + $shadowblur;
	#$image=shadow(\$image, $swidth, $sheight, $shadowblur, $shadowblursigma, $shadowx, $shadowy, $shadowopacity);
#	$image=opacity(\$image, $opacity);
#	$image->Write(filename=>$testoutput);
#
#	exit();
#}
	

if ($ARGV[0] ne "") {
	$curxptheme = $ARGV[0];

	if ($name eq "cursor-theme"){
		$name = $ARGV[0];
		my $base = basename($name);
		my $dir  = dirname($name);
		$name = $base;
		$name =~ s/(.*)\.curxptheme/$1/i;
	}

	unless (-f $curxptheme) {
		print "$curxptheme not found.";
		exit 1;
	}

	#print $name;
	$path="/tmp/sd2xc/".$name."/".$name."/";
	$basepath="/tmp/sd2xc/".$name."/";
	if ($tmppath eq "temp-sd2xc/"){
		$tmppath="$basepath"."$tmppath";	
	}
	if (! -d $path) {
		mkpath ($path);
	}
	$dummy = `$unzip -u -d $basepath $curxptheme`
}
elsif($name ne "") {	
	$path = $name."/";
} 


# make sure path and tmppath end in /
if ($path =~ /[^\/]$/) {
	$path=$path."/";
}
if ($tmppath =~ /[^\/]$/) {
	$tmppath=$tmppath."/";
}
if ($origpath =~ /[^\/]$/) {
	$origpath=$origpath."/";
}

if ($path =~ / /) {
	print ("Spaces in names, filenames, and paths not allowed at the moment.\n");
	exit 1;
}
if ($tmppath =~ / /) {
	print ("Spaces in names, filenames, and paths not allowed at the moment.\n");
	exit 1;
}
if ($origpath =~ / /) {
	print ("Spaces in names, filenames, and paths not allowed at the moment.\n");
	exit 1;
}

if (! -d $path) {
	mkdir ($path);
}
if (! -d $path."cursors/") {
	mkdir ($path."cursors/");
}
if (-d $tmppath) {
	$dummy=`rm -r $tmppath*`;
} else {
	mkdir ($tmppath);
}



$tmpscheme=$tmppath."Scheme.ini";

#print $basepath."Scheme.ini";

rewrite_ini($basepath."Scheme.ini");
#exit;

# I did this much nicer, but Perl < 5.8 choked.
open (INI, "< $tmpscheme.tmp") or die ("$tmpscheme.tmp");
open (INF, ">", $tmpscheme);
while (<INI>) {
	unless (!/=/ && !/^\s*\[/) {
		#$config_file.=$_;
		print INF $_;
	}
}
close (INI);
close (INF);

my $cfg=new Config::IniFiles(-file=>$tmpscheme) or die ("Scheme.ini in wrong format? -".$@);
my @sections=$cfg->Sections;

my $filemap={
	Arrow=>['X_cursor',
'x_cursor',
'right_ptr',
'draft_large',
'draft_small',
'top_left_arrow',
'move',
'4498f0e0c1937ffe01fd06f973665830',
'9081237383d90e509aa00f00170e968f',
"left_ptr"],
	Arrow_Down=>['arrow_Down','arrow_down'],
	Button=>"button",
	Button_Down=>"button_down",
	UpArrow=>['color-picker',
'icon',
'target',
'dotbox',
'dot_box_mask',
'closedhand',
'fcf21c00b30f7e3f83fe0dfd12e71cff',
"center_ptr"],
	UpArrow_Down=>"uparrow_down",
	Cross=>['tcross',
'crosshair',
'cross_reverse',
'diamond_cross',
'draped_box',
"cross"],
	Cross_Down=>'cross_down',
	Hand=>['hand1',
'hand2',
'pointing_hand',
'openhand',
'pointer',
'dnd-move',
'dnd-link',
'dnd-copy',
'dnd-none',
'copy',
'link',
'alias',
'640fb0e74195791501fd1ed57b41487f',
'1081e37283d90000800003c07f3ef6bf',
'4498f0e0c1937ffe01fd06f973665830',
'a2a266d0498c3104214a47bd64ab0fc8',
'3085a0e285430894940527032f8b26df',
'b66166c04f8c3109214a4fbd64a50fc8',
'9d800788f1b08800ae810202380a0822',
'e29285e634086352946a0e7090d73106',
'6407b0e94181790501fd1e167b474872',
"hand"],
	Hand_Down=>'hand_down',
	IBeam=>['xterm',
'text',
"ibeam"],
	IBeam_Down=>'ibeam_down',
	SizeNWSE=>['bottom_right_corner',
'bottom_right_corner',
'bd_double_arrow',
'lr_angle',
'size_fdiag',
'ul_angle',
'ur_angle',
'c7088f0f3e6c8088236ef8e1e3e70000',
"top_left_corner"],
	SizeNWSE_Down=>"sizenwse_down",
	SizeNESW=>['bottom_left_corner',
'fd_double_arrow',
'll_angle',
'size_bdiag',
	SizeNESW_Down=>"sizenesw_down",
'fcf1c3c7cd4491d801f1e1c78f100000',
"top_right_corner"],
	SizeWE=>['sb_h_double_arrow',
'left_side',
'sb_right_arrow',
'left_tee',
'w-resize',
'sb_left_arrow',
'e-resize',
'split_h',
'right_tee',
'row-resize',
'right_side',
'h_double_arrow',
'028006030e0e7ebffc7f7070c0600140',
'14fef782d02440884392942c11205230',
'00008160000006810000408080010102',
"size_hor"],
	SizeWE_Down=>"sizewe_down",
	SizeNS=>['double_arrow',
'bottom_side',
'top_side',
'v_double_arrow',
'sb_v_double_arrow',
'sb_down_arrow',
'up_arrow',
's-resize',
'top_tee',
'bottom_tee',
'sb_up_arrow',
'col-resize',
'split_v',
'n-resize',
'00008160000006810000408080010102'
,'2870a09082c103050810ffdffffe0204',
"size_ver"],
	SizeNS_Down=>"sizens_down",
	Help=>['question_arrow',
'5c6cd98b3f3ebcb1f9c7f1c204630408',
'd9ce0ab605698f320427677b458ad60b',
'left_ptr_help',
'dnd-ask',
'whats_this',
"help"],
	Help_Down=>'help_down',
	Handwriting=>"pencil",
	Handwriting_Down=>'handwriting_down',
	AppStarting=>['left_ptr_watch',
'08e8e1c95fe2fc01f976f1e063a24ccd',
'3ecb610c1bf2410f44200f48c40d3599',
"arrow"],
	AppStarting_Down=>'appstarting_down',
	SizeAll=>['plus',
'grabbing',
'all-scroll',
'fleur',
"size_all"],
	SizeAll_Down=>"sizeall_down",
	Wait=>['progress',
'half-busy',
'00000000000000020006000e7e9ffc3f',
'watch',
"wait"],
	NO=>['dnd-no-drop',
'forbidden',
'not-allowed',
'pirate',
'tcross',
'03b6e0fcb3499374a867c041f52298f0',
'crossed_circle',
'circle',
"cross"],
	NO_Down=>"no_down"
};



foreach my $section (@sections) {
	my ($filename, $filenamelc);

	if ($section =~ /Description/i){
		my $i = 0;
		while ($cfg->val($section, $i) ne ""){
			$comment = $comment." ".$cfg->val($section, $i);
			$i = $i + 1;
		}
	}

	# Tolerate all lower case image names
	$filename=$basepath.$section.".png";
	$filenamelc=$basepath.lc($section).".png";
	unless (-f $filename || -f $filenamelc) {
		next;
	}
	if (-f $filenamelc && $filenamelc ne $filename){ $dummy = `cp $filenamelc $filename`; }

	my ($image, $x, $frames, $width, $height, $curout);

	$image=Image::Magick->new;
	$x=$image->Read($filename);
	warn "$x" if "$x";

	$frames=$cfg->val($section, 'Frames');
	$width=$image->Get('width')/$frames;
	$height=$image->Get('height');

	if (defined($filemap->{$section})) {
		$curout=$filemap->{$section};
	} else {
		$curout=$section;
	}

	my $array=-1;
	eval {
		if (defined (@{$curout}[0])) { };
	};
	unless ($@) {
		$array=0;
	}

	my $img_processed=0;
	my $real_file="";
	my $preoutfile="";

	LOOP:
		my $outfile;
	
		if ($array > -1) {
			if (defined (@{$curout}[0])) {
				$preoutfile=pop @{$curout};
			} else {
				next;
			}
		} else {
			$preoutfile=$curout;
		}
		$outfile=$path."cursors/".$preoutfile;
	
		my $yoffset = $shadowy + $shadowblur;
		my $xoffset = $shadowx + $shadowblur;
		my $swidth = ($width + $xoffset + $shadowblur)*$newsize/100;
		my $sheight = ($height + $yoffset + $shadowblur)*$newsize/100;
		$rollpixels = int(roundup(2 * (($newsize / 100) - 1)) / 2);
		my $hotspotx = int(($cfg->val($section,'Hot spot x') + $rollpixels)*$newsize/100);
		my $hotspoty = int(($cfg->val($section,'Hot spot y') + $rollpixels)* $newsize/100);

		# Don't flip certain cursors
		#if ($section ne "SizeNWSE" && $section ne "SizeNESW" && $section ne "Wait"){
			if ($flip eq "before"){
				$hotspotx = $width - $hotspotx;
			} 
			if ($flip eq "after"){
				$hotspotx = int(roundup($swidth - $hotspotx));
			}
		#}

		my $i=0;

		# Process and Output images if not yet done
	

		if ($img_processed eq "0"){

			if ($verbose) {
				print "Creating $filename\n";
			}

			$real_file = $preoutfile;
			for (my $i=0; $i<$frames; $i++) {

				# keep track of this for screenshot-large
				if ($frames > $maxframes){ $maxframes = $frames; }
				if ($height > $maxheight){ $maxheight = $height; }
				if ($width > $maxwidth){ $maxwidth = $width; }
				if ($shadow){
					if ($sheight > $maxheight){ $maxheight = $sheight; }
					if ($swidth > $maxwidth){ $maxwidth = $swidth; }
				}

				my ($tmpimg, $outfile);
				$outfile=$tmppath.$section.'-'.$i.'.png';
				$tmpimg=$image->Clone();
		
	
				$x=$tmpimg->Crop(width=>$width, height=>$height, x=>$i*$width, y=>0);
				warn "$x" if "$x";
	
				if ($newsize ne "100"){
					$tmpimg=resize(\$tmpimg, $newsize);
				}	

				if ($opacity < 100)
				{
					$tmpimg=opacity(\$tmpimg, $opacity);
				}

				# Flip back on certain cursors - more correct to do in these special cases
				if ($lefthanded){
					if ($section eq "SizeNWSE" || $section eq "SizeNESW"){ # || $section eq "Wait"){
						$tmpimg->Flop();
					}
				}

				if ($flip eq "before"){
					$tmpimg->Flop();
				}

				if ($shadow)
				{
					$tmpimg=shadow(\$tmpimg, $swidth, $sheight, $shadowblur, $shadowblursigma, $shadowx, $shadowy, $shadowopacity);
				} else {
					# A HUGE HACK TO PREVENT TRANSPARENCY DARKENING IN IMAGES WITH TRANSPARENCY ALREADY IN THEM - NO IDEA WHY IT WORKS
					$tmpimg=fiximage(\$tmpimg, $swidth, $sheight, $shadowblur, $shadowblursigma, $shadowx, $shadowy, $shadowopacity);
				}

				if ($flip eq "after"){
					$tmpimg->Flop();
				}
	
				$x=$tmpimg->Write($outfile);
			
				warn "$x" if "$x";
			}
		}

	
		if ($img_processed eq "0"){
			open (FH, "| $generator > \"$outfile\"");
			if ($verbose) {
				print "Converting $section -> $outfile\n";
			}

			# Manage the order that frames are displayed
			# If there is a _Script, process as such
			my $section_script=$section."_Script";
			if (defined ($cfg->val($section_script, "0"))){
				my $scripti = 0;
				my $i = 0;
				my $getinfo;
				my $interval;
				my $startframe;
				my $endframe;
				my $whichframes;
	
				while ($cfg->val($section_script, $scripti) ne ""){
					$startframe = "";
					$endframe = "";
	
					$getinfo=$cfg->val($section_script, $scripti);
					($whichframes, $interval) = split (/,/ , $getinfo);
					#print $frames." ".$interval."\n";
	
					($startframe, $endframe) = split (/-/ , $whichframes);
	
					if ($interval > 1000000){
						$interval = 1000000;
					}
	
					if ($endframe !~ /\d/ ){
						$endframe = $startframe;
					}
	
									
					for (my $i=$startframe-1; $i<$endframe; $i++) {
						my ($tmpimg, $outfile);
						$outfile=$tmppath.$section.'-'.$i.'.png';
	# 		
						if (-e "$outfile"){
							print FH "32 ".
							$hotspotx." ".
							$hotspoty." ".
							$outfile." ".
							$interval."\n";
						}	
						
					}
	
					$scripti = $scripti + 1;
				}
				
				
			} else {	# Otherwise do normal static or normal looping animated
				for (my $i=0; $i<$frames; $i++) {
					my ($outfile);
					$outfile=$tmppath.$section.'-'.$i.'.png';
		
					print FH  "32 ".
					$hotspotx." ".
					$hotspoty." ".
					$outfile." ".
					$cfg->val($section,'Interval')."\n";
		
					
				}
			}
			close (FH);
			$img_processed=1;
		} else {
			if ($verbose) {
				print "Creating symlink $outfile -> $real_file\n";
			}
			$dummy=`if [ -f $outfile ]; then rm $outfile; fi; ln -s $real_file $outfile`;
		}
		

	if ($array > -1) {
		goto LOOP;
	}

}

if ($verbose) {
	print "Writing theme index file.\n";
}


$comment = $comment." - Converted by GrynayS";

open (FH, "> ${path}index.theme");
print FH <<EOF;
[Icon Theme]
Name=$name
Comment=$comment
Example=left_ptr
Inherits=$inherits
EOF
close (FH);

if ($verbose) {
	print "Theme written to ${path}\n";
}

if (!$nozip){

	$dummy = `cd $basepath; pwd; tar cf $origpath$name.tar $name; gzip $origpath$name.tar;`;

	if ($verbose) {		
		print "Theme zipped into ./$name.tar.gz\n";
	}

}

if ($install){

	$dummy = `mkdir -p ~/.icons; cp -Rp $basepath$name ~/.icons/;`;
	if ($verbose) {	
		print "Theme installed into ~/.icons/\n";
	}
}

if ($makescreen){
	if ($verbose) {	
		print "Making screenshot $origpath$name-screenshot.png\n";
	}
	$dummy =`montage -geometry +5+5 -title '$name' $tmppath*-0.png $origpath$name-screenshot.png`;
}

print "$maxframes \n";


# Very dirty still.  Will probably add more features eventually.

if ($makescreenfull){
	if ($verbose) {	
		print "Making full screenshot $origpath$name-screenshot-full.png\n";
	}

	$dummy=`cd $origpath`;

	my $allnamestring;
	my $namestring;
	my $filename;
	my $geometry="-geometry '".$maxwidth."x".$maxheight."+0+0'";
	#my $geometry="-geometry x".$maxheight."+0+0";

	#my $tile="-tile ".$maxframes."x1 ";
	my $tile="-tile x1 ";
	my $dejavu=`convert -list font | grep "^DejaVu-Sans-Bold " | wc -l`;
	my $font;
	if (chomp($dejavu) eq "1"){ $font = "-font DejaVu-Sans-Bold "; } else { $font = "" };

	foreach my $section (@sections) {

		$namestring="";

		if ($section eq "Arrow" ||
		$section eq "Cross" ||
		$section eq "Hand" ||
		$section eq "IBeam" ||
		$section eq "UpArrow" ||
		$section eq "SizeNWSE" ||
		$section eq "SizeNESW" ||
		$section eq "SizeWE" ||
		$section eq "SizeNS" ||
		$section eq "Help" ||
		$section eq "Handwriting" ||
		$section eq "AppStarting" ||
		$section eq "SizeAll" ||
		$section eq "Wait" ||
		$section eq "NO"){


			# create cursor title images
			#-annotate +11+11 '$section' -blur 0x2
			$dummy = `convert  -background none -size 100x$maxheight xc:none $font -pointsize 12  -draw "text 10,10 '$section'" $tmppath$name-$section-title.png`;

			for (my $i=0; $i<$maxframes; $i++) {			
				$filename = $tmppath.$section."-".$i.".png";
				if (-e $filename){
					$namestring = "$namestring"."$filename ";
				}
			}

			# create cursor image group
			$dummy =`montage -background none $geometry $tile $namestring $tmppath$name-$section-noname.png`;
			# concatenate cursor title with cursor images
			$dummy =`montage -background none -geometry +0+0  -tile x1 -label "" $tmppath$name-$section-title.png $tmppath$name-$section-noname.png $tmppath$name-$section.png`;

		}
	}

	$allnamestring = "$tmppath$name-Arrow.png $tmppath$name-Wait.png $tmppath$name-AppStarting.png $tmppath$name-Hand.png $tmppath$name-Cross.png $tmppath$name-IBeam.png $tmppath$name-UpArrow.png $tmppath$name-SizeWE.png $tmppath$name-SizeNS.png $tmppath$name-SizeNWSE.png $tmppath$name-SizeNESW.png $tmppath$name-SizeAll.png $tmppath$name-Handwriting.png $tmppath$name-NO.png"; 
	
	#transparent
	#$dummy =`montage -background none -geometry +0+0 $font -pointsize 10 -tile 1x -title '$name' $allnamestring $tmppath$name-screenshot-full.png`;
  	
	# white
	$dummy =`montage -background white -geometry +0+0 $font -pointsize 10 -tile 1x -title '$name' $allnamestring $tmppath$name-screenshot-full.png`;

	#$dummy =`convert -background none pattern:checkerboard $tmppath$name-screenshot-full.png -bordercolor snow -background black -polaroid 0 $origpath$name-screenshot-full.png`;
	#$dummy =`convert -size 500x500 -seed 4321 plasma:white-blue $tmppath$name-background.png`;
	#$dummy =`convert -size 500x500 plasma:grey75-grey75  -blur 0x2  -channel G  -separate $tmppath$name-background.png`;
	#$dummy =`composite $tmppath$name-screenshot-full.png $tmppath$name-background.png  $tmppath$name-screenshot-large-pre1.png`;

	# create checkerboard
	#$dummy=`convert -size 500x500 pattern:checkerboard -normalize -fill "#CCC" -opaque black   -fill "#EEE"  -opaque white  $tmppath-checker.png`;

	# add checkboard
	#$dummy =`composite $tmppath$name-screenshot-full.png $tmppath-checker.png $tmppath$name-screenshot-large-pre1.png`;

	



	#polaroid border
	#$dummy =`convert $tmppath$name-screenshot-large-pre1.png -bordercolor snow -background black -polaroid 0 $origpath$name-screenshot-full.png`;
	
	#fuzzy border
	#$dummy =`convert $tmppath$name-screenshot-large-pre1.png -matte -virtual-pixel transparent -channel A -blur 0x8  -evaluate subtract 50%  -evaluate multiply 2.001  $origpath$name-screenshot-full.png`;

	#rounded border
	#$dummy =`convert -page +4+4 $tmppath$name-screenshot-large-pre1.png  \\( +clone -background navy -shadow 60x4+4+4 \\) +swap  -background none -mosaic    -depth 8  -quality 95  $origpath$name-screenshot-full.png`;

	#sunken
 	#$dummy =`convert  $tmppath$name-screenshot-large-pre1.png  +raise 8x8 $origpath$name-screenshot-full.png`;

	#granite
	#$dummy =`convert  $tmppath$name-screenshot-full.png  granite: $origpath$name-screenshot-full.png`;

	# Just copy
	$dummy =`convert $tmppath$name-screenshot-full.png  $origpath$name-screenshot-full.png`;

}

if (!$keeptemp){
	if ($ARGV[0] ne ""){
		$dummy = `rm -r $basepath`;
		if ($verbose) {	
			print "Removed temp directory $basepath\n";
		}
	} else {
		$dummy = `rm -r $tmppath`;
		if ($verbose) {
			print "Removed temp directory $tmppath\n";
		}
	}

}

if ($verbose) {
	print "Done.\n";
}












