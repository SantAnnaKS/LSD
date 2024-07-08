#*************************************************************
#
#	LSD 8.1 - July 2023
#	written by Marco Valente, Universita' dell'Aquila
#	and by Marcelo Pereira, University of Campinas
#
#	Copyright Marco Valente and Marcelo Pereira
#	LSD is distributed under the GNU General Public License
#
#	See Readme.txt for copyright information of
#	third parties' code used in LSD
#
#*************************************************************

#*************************************************************
# SETUP.TCL
# Tcl script used to install LSD in all platforms.
#*************************************************************

wm withdraw .


#
# setup configuration values
#

set _LSD_NAME_ "LSD Laboratory for Simulation Development"
set _LSD_PUBLISHER_ "Marco Valente and Marcelo Pereira"
set _LSD_VERSION_ "8.1"
set _LSD_DATE_ "December 26 2023"
set _LSD_SIZE_KB_ 552326

set LsdDir LSD
set LsdSrc src
set LsdIco $LsdSrc/icons
set winRoot "C:/"

set linuxPmPkg(apt)	[ list	build-essential 	make	gdb		gnuplot		xterm	multitail	zlib1g-dev		tcl-dev			tk-dev			]
set linuxPmPkg(yum)	[ list	gcc-c++ 			make	gdb		gnuplot		xterm	multitail	zlib-devel		tcl-devel		tk-devel		]
set linuxPmPkg(dnf)	[ list	gcc-c++ 			make	gdb		gnuplot		xterm	multitail	zlib-devel		tcl-devel		tk-devel		]
set linuxPmPkg(zyp)	[ list	gcc-c++ 			make	gdb		gnuplot		xterm	multitail	zlib-devel		tcl-devel		tk-devel		]
set linuxPmPkg(urp)	[ list	gcc-c++ 			make	gdb		gnuplot		xterm	multitail	lib64z-devel	lib64tcl-devel	lib64tk-devel	]
set linuxPmPkg(apk)	[ list	g++					make	gdb		gnuplot		xterm	multitail	zlib-dev		tcl-dev			tk-dev			]
set linuxPmCmd(apt) "apt-get install"
set linuxPmCmd(yum) "yum install"
set linuxPmCmd(dnf) "dnf install"
set linuxPmCmd(zyp) "zypper install"
set linuxPmCmd(urp) "urpmi"
set linuxPmCmd(apk) "apk add"
set linuxDefPm "apt"

set linuxMkFile "makefile-linux.txt"
set linuxOptFile "system_options-linux.txt"
set notInstall [ list .git/* installer/* lwi/* Rpkg/* Manual/src/* ]

# absolute reference paths
set homeDir [ file normalize "~/." ]
set scptDir [ file normalize "[ file dirname [ info script ] ]/.." ]
set macZip [ file normalize "$scptDir/../Package/LSD-archive-mac.zip" ]


#
# start LSD Tcl/Tk environment
#

# load support tools
set RootLsd "$scptDir"
source "$RootLsd/$LsdSrc/gui.tcl"
source "$RootLsd/$LsdSrc/file.tcl"
source "$RootLsd/$LsdSrc/util.tcl"

# register the Tcl error handler
proc log_tcl_error { show errorInfo message } {
	ttk::messageBox -parent "" -type ok -title Error -icon error -message "Internal error" -detail "Please try again.\nIf the error persists, please contact the LSD developers.\n\nDetails:\n$errorInfo\n$message\n\nExiting now."

	exit 255
}

# set main window
set fonttype $DefaultFontSize
set dim_character $DefaultFontSize
set small_character [ expr { $dim_character - $deltaSize } ]

setstyles
setglobkeys . 0
icontop . lsd
. configure -background $colorsTheme(bg)


#
# adjust platform-specific defaults
#

# check if all required components are installed
if { ! [ check_components ] } {
	ttk::messageBox -parent "" -type ok -title Error -icon error -message "Invalid platform" -detail "LSD cannot be installed in this computer.\n\nExiting now."
	exit 1
}

if { $CurPlatform eq "mac" } {
	set notInstall [ concat $notInstall *.exe *.dll *.bat gnu/* src/installer-loader-linux.sh ]

	# make sure PATH is complete
	if { [ string first "/usr/local/bin" $env(PATH) ] < 0 } {
		set env(PATH) "/usr/local/bin:$env(PATH)"
	}

	# create temporary folder
	try {
		close [ file tempfile temp ]
		file delete -force $temp
		set filesDir [ file normalize [ file join [ file dirname $temp ] [ file tail $temp ] ] ]
		file mkdir "$filesDir"
	} on error result {
		ttk::messageBox -parent "" -type ok -title Error -icon error -message "Cannot create temporary files" -detail "Please check your file system and try again.\n\nExiting now."
		exit 2
	}
} elseif { $CurPlatform eq "linux" } {
	set notInstall [ concat $notInstall *.exe *.dll *.bat LMM.app/* $LsdSrc/LSD.app/* gnu/* src/installer-loader-linux.sh ]
	set filesDir [ file normalize [ pwd ] ]
} else {
	set notInstall [ concat $notInstall *.sh LMM.app/* $LsdSrc/LSD.app/* ]
	set filesDir [ file normalize [ pwd ] ]
}

#
# check default LSD directory location
#

if { [ info exists env(LSDROOT) ] && [ file exists [ file dirname $env(LSDROOT) ] ] } {
	set homeDir [ file dirname $env(LSDROOT) ]
	set RootLsd [ file normalize $env(LSDROOT) ]

} else {
	if { [ string equal $CurPlatform mac ] || [ string equal $CurPlatform linux ] } {
		if { [ string first " " "$homeDir" ] < 0 } {
			set RootLsd "~/$LsdDir"
		} else {
			ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Home directory includes space(s)" -detail "The system directory '$homeDir' is invalid for installing LSD.\nLSD subdirectory must be located in a directory with no spaces in the full path name.\n\nYou may use another directory if you have write permissions to it.\n\nExiting now."
			set homeDir "/"
			set RootLsd "/$LsdDir"
		}

	} else {
		if { [ string first " " "$homeDir" ] < 0 } {
			set RootLsd [ file normalize "~/$LsdDir" ]
		} elseif [ file exists $winRoot ] {
			set homeDir "$winRoot"
			set RootLsd "${winRoot}$LsdDir"
		} else {
			set homeDir "/"
			set RootLsd "/$LsdDir"
		}
	}
}


#
# unzip files if not done yet and adjust directory names if needed
#

if [ string equal $CurPlatform mac ] {
	waitbox .wait "Decompressing..." "Decompressing files.\n\nIt may take a while, please wait..." "" 0 ""
	try {
		set result [ exec unzip -oqq $macZip -d $filesDir ]
		destroytop .wait
	} on error result {
		destroytop .wait
		ttk::messageBox -parent "" -type ok -title Error -icon error -message "Disk full or corrupt package" -detail "The computer storage is full or the installation package does not contain the required files to install LSD.\n\nPlease check your disk space or try to download again the installation package.\n\nExiting now."
		exit 3
	}

} elseif [ string equal $CurPlatform linux ] {
	catch { file rename -force "$filesDir/Work.template" "$filesDir/Work" }
}


#
# select files to install
#

set files [ findfiles "$filesDir" * 1 ]
foreach rem $notInstall {
	set toRemove [ lsearch -glob -all -inline $files $rem ]
	foreach f $toRemove {
		set pos [ lsearch -exact $files $f ]
		set files [ lreplace $files $pos $pos ]
	}
}

# check if bare minimum is there
if { [ llength $files ] < 100 || [ string first Readme.txt $files ] < 0 || [ string first lsdmain.cpp $files ] < 0 || [ string first groupinfo.txt $files ] < 0 } {
	ttk::messageBox -parent "" -type ok -title Error -icon error -message "Corrupt installation package" -detail "The installation package does not contain the required files to install LSD.\n\nPlease try to download again the installation package.\n\nExiting now."
	exit 4
}


#
# create main (select directory) window
#

ttk::frame .dir
ttk::frame .dir.choice
ttk::frame .dir.choice.blk
ttk::label .dir.choice.blk.lab -text "Directory to install LSD"
ttk::entry .dir.choice.blk.where -textvariable RootLsd -width 40 -justify center
pack .dir.choice.blk.lab .dir.choice.blk.where
bind .dir.choice.blk.where <Return> { .b.ok invoke }
ttk::frame .dir.choice.but
ttk::label .dir.choice.but.lab
ttk::button .dir.choice.but.browse -text Browse -width -1 -command {
	set dir [ tk_chooseDirectory -initialdir "$homeDir" -title "Choose a directory" ]
	if { $dir != "" } {
		set RootLsd "$dir"
	}
	.dir.choice.blk.where selection range 0 end
	focus .dir.choice.blk.where
}
pack .dir.choice.but.lab .dir.choice.but.browse
pack .dir.choice.blk .dir.choice.but -padx 5 -side left
ttk::label .dir.obs -text "If LSD is already installed in the\nselected directory, it will be updated" -justify center

if [ string equal $CurPlatform windows ] {

	if { ! [ catch { exec net session >nul 2>&1 } ] } {
		set wadmin 1
		set wall 1
		if [ file exists $winRoot ] {
			set RootLsd "${winRoot}$LsdDir"
		} else {
			set RootLsd "/$LsdDir"
		}
	} else {
		set wadmin 0
		set wall 0
	}

	ttk::checkbutton .dir.wall -variable wall -text "Install for all users" -command {
		if { $wall } {
			if [ file exists $winRoot ] {
				set RootLsd "${winRoot}$LsdDir"
			} else {
				set RootLsd "/$LsdDir"
			}
		} elseif { [ string first " " "$homeDir" ] < 0 } {
			set RootLsd [ file normalize "~/$LsdDir" ]
		}
	}

	pack .dir.choice .dir.wall .dir.obs -pady 5

	if { $wadmin } {
		tooltip::tooltip .dir.wall "Allow any user logged in this computer to use LSD"
	} else {
		tooltip::tooltip .dir.wall "To enable this option run installer as administrator"
		.dir.wall configure -state disabled
	}
} else {
	pack .dir.choice .dir.obs -pady 5
}

if { [ info exists xcode ] && [ info exists gnuplot ] } {
	ttk::label .dir.extra -text "Xcode command line tools and\nGnuplot graphical terminal\nare not available and will be installed" -justify center
	pack .dir.extra -pady 5
} else {
	if [ info exists xcode ] {
		ttk::label .dir.extra -text "Xcode command line tools are\nnot available and will be installed" -justify center
		pack .dir.extra -pady 5
	} elseif { [ info exists gnuplot ] && $wadmin } {
		ttk::label .dir.extra -text "Gnuplot graphical terminal seems\nunavailable and will be installed" -justify center
		pack .dir.extra -pady 5
	}
}

if { [ info exists linuxPkgMiss ] && [ llength $linuxPkgMiss ] > 0 } {
	ttk::label .dir.extra -text "Some Linux packages are not\navailable and will be installed:\n$linuxPkgMiss" -justify center
	pack .dir.extra -pady 5
}

ttk::label .dir.lic -text "LSD is free software and comes\nwith ABSOLUTELY NO WARRANTY\nSee Readme.txt for copyright information" -justify center
pack .dir.lic -pady 5
pack .dir -padx 10 -pady 10

okcancel . b { set done 1 } { set done 2 }

wm geometry . +[ getx . centerS ]+[ gety . centerS ]
settop . "LSD Installer" { set done 2 } "" yes

tooltip::tooltip .dir.choice.but.browse "Choose a different\ninstallation directory"

set newInst 1


#
# check user option
#

while 1 {
	while 1 {
		.dir.choice.blk.where selection range 0 end
		focus .dir.choice.blk.where

		set done 0
		tkwait variable done

		if { $done == 2 } {
			break
		}

		if { [ catch { set RootLsd [ file normalize $RootLsd ] } ] || ! [ file exists [ file dirname "$RootLsd" ] ] } {
			ttk::messageBox -type ok -title Error -icon error -message "Invalid directory path/name" -detail "The directory path '$RootLsd' is invalid.\nA valid directory path and names must be supplied. Only valid characters for directory names are accepted. The parent directory to the LSD subdirectory must exist.\n\nPlease choose another path/name."
			continue
		}

		if { [ string first " " "$RootLsd" ] >= 0 } {
			ttk::messageBox -type ok -title Error -icon error -message "Directory includes space(s)" -detail "The chosen directory '$RootLsd' is invalid for installing LSD.\nLSD subdirectory must be located in a directory with no spaces in the full path name.\n\nPlease choose another directory."
			continue
		}

		if { ! [ file writable [ file dirname "$RootLsd" ] ] } {
			ttk::messageBox -type ok -title Error -icon error -message "Directory not writable" -detail "The chosen directory '[ file dirname "$RootLsd" ]' is invalid for installing LSD.\nLSD subdirectory must be located in a directory where the user has write permission.\n\nPlease choose another directory."
		} else {
			break
		}
	}

	if { $done == 1 && [ file exists $RootLsd ] } {
		if { ! [ string equal [ ttk::messageBox -type okcancel -title Warning -icon warning -default ok -message "Directory already exists" -detail "Directory '$RootLsd' already exists.\n\nPress 'OK' to continue and update installed files or 'Cancel' to abort installation." ] ok ] } {
			continue
		} else {
			set newInst 0
			if [ catch { file delete -force "$RootLsd/lmm" "$RootLsd/lmm.exe" "$RootLsd/lmm64.exe" "$RootLsd/run.bat" "$RootLsd/run.sh" "$RootLsd/$LsdSrc/system_options.txt" {*}[ glob -nocomplain -directory "$RootLsd/$LsdSrc" *.o ] "$env(HOME)/Desktop/lsd.desktop" } ] {
				ttk::messageBox -type ok -title Error -icon error -message "Cannot remove old files" -detail "Cannot replace the existing LSD files by the upgraded ones.\n\nPlease try reinstalling after closing any open instance of LSD/LMM.\n\nExiting now."

				exit 5
			}
		}
	}

	if { $done == 2 } {
		if [ string equal [ ttk::messageBox -type okcancel -title "Exit?" -icon info -default ok -message "Exit installation?" -detail "LSD installation is not complete.\n\nPress 'OK' to confirm exit." ] ok ] {
			exit 6
		}
	} else {
		break
	}
}

if { [ info exists env(LSDROOT) ] && [ file normalize $env(LSDROOT) ] ne [ file normalize $RootLsd ] } {
	ttk::messageBox -parent "" -type ok -title Error -icon error -message "Invalid LSDROOT value" -detail "Please make sure the environment variable LSDROOT points to the directory where LSD is going to be installed.\n\nPlease try reinstalling after changing the LSDROOT variable or install to the directory it points to (the default).\n\nExiting now."
	exit 7
}

if { ! [ file exists "$RootLsd" ] && [ catch { file mkdir "$RootLsd" } ] } {
	ttk::messageBox -type ok -title Error -icon error -message "Cannot create LSD directory" -detail "The chosen directory '$RootLsd' could not be created.\nLSD subdirectory must be located in a directory where the user has write permission.\n\nExiting now."
	exit 7
}

wm withdraw .


#
# copy files to LSD directory
#

# create progress bar window
set n 0
set nFiles [ llength $files ]
set inst [ progressbox .inst "LSD Installer" "Copying files" "File" $nFiles { set done 2 } "" ]

foreach f $files {
	try {
		file mkdir [ file dirname "$RootLsd/$f" ]
		file copy -force "$filesDir/$f" "$RootLsd/$f"
	} on error result {
		break
	}

	incr n
	if { ( $n + 1 ) % 20 == 0 } {
		prgboxupdate .inst $n
	}

	if { $done == 2 } {
		if [ string equal [ ttk::messageBox -parent "" -type okcancel -title "Exit?" -icon info -default ok -message "Exit installation?" -detail "LSD installation is not complete.\n\nPress 'OK' to confirm exit." ] ok ] {
			exit 8
		} else {
			set done 1
		}
	}
}


#
# remove temporary files
#

if [ string equal $CurPlatform mac ] {
	$inst configure -text "Removing temporary files..."
	catch { file delete -force $filesDir }
}

destroytop .inst

if { $n != $nFiles } {
	if { ! [ info exists result ] } {
		set result "(no information)"
	}
	ttk::messageBox -parent "" -type ok -title Error -icon error -message "Incomplete installation" -detail "The installation could not copy the required files to run LSD ([ expr { $nFiles - $n } ] files failed).\n\nError detail:\n$result\n\nPlease try reinstalling after closing any open instance of LSD/LMM or download again the installation package.\n\nExiting now."

	if { $newInst } {
		catch { file delete -force $RootLsd }
	}

	exit 9
}


set issues [ list ]


#
# set LSD library folder in the user PATH environment variable in Windows
#

if [ string equal $CurPlatform windows ] {

	if { $wall } {
		set sysPath 1
		if { [ llength $existGCCsys ] == 0 && [ llength $existDLLsys ] == 0 } {
			set res [ add_win_path "$RootLsd/gnu/bin" system end ]
			set wconfl 0
		} else {
			if [ string equal [ ttk::messageBox -parent "" -type yesno -default yes -title Warning -icon warning -message "Potentially conflicting software installed" -detail "Software components included in LSD are already installed in the computer.\n\nYou may want to set the software components included in LSD as the new system default. If not, LSD will use the existing software components but it is not guaranteed they are compatible with LSD.\n\nPress 'Yes' to set LSD components as the system default, or 'No' to continue the installation anyway." ] yes ] {
				set res [ add_win_path "$RootLsd/gnu/bin" system begin ]
				set wconfl 0
			} else {
				set res [ add_win_path "$RootLsd/gnu/bin" system end ]
				set wconfl 1
			}
		}
	} else {
		# add LSD to user PATH environment variable if no conflict exists or
		# ask about changing the system PATH if potential conflicts exist
		set sysPath 0
		if { [ llength $existGCC ] == 0 && [ llength $existDLL ] == 0 } {
			set res [ add_win_path "$RootLsd/gnu/bin" user end ]
			set wconfl 0
		} elseif { [ llength $existGCCsys ] == 0 && [ llength $existDLLsys ] == 0 } {
			set res [ add_win_path "$RootLsd/gnu/bin" user begin ]
			set wconfl 0
		} elseif { $wadmin } {
			if [ string equal [ ttk::messageBox -parent "" -type yesno -default yes -title Warning -icon warning -message "Potentially conflicting software installed" -detail "Software components included in LSD are already installed in the computer.\n\nYou may want to set the software components included in LSD as the new system default. If not, LSD will use the existing software components but it is not guaranteed they are compatible with LSD.\n\nPress 'Yes' to set LSD components as the system default, or 'No' to continue the installation anyway." ] yes ] {
				set res [ add_win_path "$RootLsd/gnu/bin" system begin ]
				set sysPath 1
				set wconfl 0
			} else {
				set res [ add_win_path "$RootLsd/gnu/bin" user end ]
				set wconfl 1
			}
		} else {
			ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Potentially conflicting software installed" -detail "Software components included in LSD are already installed in the computer.\n\nLSD will use the existing software components but it is not guaranteed they are compatible with LSD.\n\nIf LSD does not perform as expected, you may try to re-run LSD installer as administrator, and then choose to set the software components included in LSD as the new system default."
			set res [ add_win_path "$RootLsd/gnu/bin" user end ]
			set wconfl 1
		}
	}

	if { ! $res } {
		if [ string equal [ ttk::messageBox -parent "" -type okcancel -default ok -title Error -icon error -message "Cannot add LSD to PATH" -detail "LSD libraries folder could not be added to the user PATH environment variable.\n\nYou may try to repeat the installation or manually add the folder '$RootLsd/gnu/bin' to the PATH variable following the steps described in 'Readme.txt'.\n\nPress 'OK' if you want to continue the installation anyway or 'Cancel' to exit." ] ok ] {
			if { $sysPath } {
				lappend issues "LSD libraries not in PATH (setx PATH \"%PATH%;$RootLsd/gnu/bin /m\")"
			} else {
				lappend issues "LSD libraries not in PATH (setx PATH \"%PATH%;$RootLsd/gnu/bin\")"
			}
		} else {
			if { $newInst } {
				catch { file delete -force $RootLsd }
			}

			exit 10
		}
	}

	if { $wconfl && [ llength $existGCC ] > 0 } {
		ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Potentially unsupported C++ compiler installed" -detail "There is another C++ compiler already installed:\n$msgGCC\n\nLSD will use it but it is not guaranteed this compiler is updated and configured to support LSD.\n\nCheck in 'Readme.txt' the required steps to properly configure your external compiler or remove/uninstall it before using LSD.\n\nInstallation will continue but you may have to fix this problem so LSD can work reliably."

		foreach comp $existGCC {
			lappend issues "External compiler maybe not configured (del $comp)"
		}
	}

	if { $wconfl && [ llength $existDLL ] > 0 } {
		ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Potentially conflicting libraries installed" -detail "There are libraries used by LSD already installed:\n$msgDLL\n\nLSD will use them but it is not guaranteed they are updated and compatible to support LSD.\n\nYou may want to remove or update them before using LSD.\n\nInstallation will continue but you may have to fix this problem so LSD can work reliably."

		foreach dll $existDLL {
			lappend issues "External library maybe not updated (del $dll)"
		}
	}
}


#
# add icons to desktop and program menu, perform registration if needed
#

cd $RootLsd
if [ string equal $CurPlatform windows ] {

	if { $wall } {
		set wopt "/s"
		set regPath "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\LSD"
	} else {
		set wopt ""
		set regPath "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\LSD"
	}

	set res [ catch { exec $RootLsd/add-shortcut-windows.bat $wopt } result ]

	catch {
		registry set $regPath DisplayIcon "[ file nativename $RootLsd/$LsdIco ]\\lsd.ico" sz
		registry set $regPath DisplayName "$_LSD_NAME_" sz
		registry set $regPath DisplayVersion "$_LSD_VERSION_" sz
		registry set $regPath Publisher "$_LSD_PUBLISHER_" sz
		registry set $regPath EstimatedSize $_LSD_SIZE_KB_ dword
		registry set $regPath InstallLocation "[ file nativename $RootLsd ]" sz
		registry set $regPath VersionMajor [ lindex [ split $_LSD_VERSION_ . ] 0 ] dword
		registry set $regPath VersionMinor [ lindex [ split $_LSD_VERSION_ . ] 1 ] dword
		registry set $regPath NoModify 1 dword
		registry set $regPath NoRepair 1 dword
		registry set $regPath UninstallString "[ file nativename $RootLsd ]\\uninstall-windows.bat /s" sz
	}
} elseif [ string equal $CurPlatform linux ] {
	set res [ catch { exec $RootLsd/add-shortcut-linux.sh } result ]
} else {
	ttk::messageBox -parent "" -type ok -title "LSD Installation" -icon info -message "User interaction required" -detail "The next step of installation will require the user to provide the system password.\n\nA Terminal window will open and the interaction must be performed there.\n\nThis is required so LSD can be installed out of the macOS quarantine zone for new executable files."
	set wait [ waitbox .wait "Installing..." "Installing LSD" "1. type the macOS user password and press <Return>\n2. if required, allow the Terminal to control Finder\n3. Terminal window will close/disable when done\n" 1 "" ]

	set scpt [ open "$env(TMPDIR)/add_shortcut.as" w ]
	puts $scpt "tell application \"Terminal\""
	set openMsg "clear; echo \\\"Installing LSD\\nPlease wait for this window to close/deactivate automatically.\\nType your password and press <Return>:\\\"; "
	set shortcutInsta "/bin/bash -c \\\"${RootLsd}/add-shortcut-mac.sh 2>&1 /dev/nul\\\"; "
	set closeMsg "touch \$TMPDIR/shortcut-done.tmp; exit"
	puts $scpt "\tdo script \"${openMsg}${shortcutInsta}${closeMsg}\""
	puts $scpt "end tell"
	close $scpt
	exec chmod +x "$env(TMPDIR)/add_shortcut.as"

	file delete -force "$env(TMPDIR)/shortcut-done.tmp"
	set res [ catch { exec osascript "$env(TMPDIR)/add_shortcut.as" } ]

	if { ! $res } {
		set timeout 1800
		set elapsed 0
		while { ! [ file exists "$env(TMPDIR)/shortcut-done.tmp" ] && $elapsed < $timeout } {
			$wait configure -text [ format "%02d:%02d" [ expr { int( $elapsed / 60 ) } ] [ expr { $elapsed % 60 } ] ]
			update
			after 1000
			incr elapsed
		}

		if { $elapsed >= $timeout } {
			set res 1
			set result timeout
		}

	} else {
		set result $res
	}

	file delete -force "$env(TMPDIR)/add_shortcut.as" "$env(TMPDIR)/shortcut-done.tmp"
	destroytop .wait
}

if { $res } {
	if [ string equal [ ttk::messageBox -parent "" -type okcancel -default cancel -title Error -icon error -message "Cannot create LSD shortcuts" -detail "The creation of LSD program shortcuts failed ($result).\n\nYou may try to repeat the installation or do a manual install following the steps described in 'Readme.txt'.\n\nPress 'OK' if you want to continue the installation anyway or 'Cancel' to exit." ] ok ] {

		lappend issues "LSD program shortcuts missing (add-shortcut-$CurPlatform)"
	} else {
		if { $newInst } {
			catch { file delete -force $RootLsd }
		}

		exit 11
	}
}


#
# install macOS Xcode command line tools if required
#

if [ info exists xcode ] {
	ttk::messageBox -parent "" -type ok -title "Xcode Installation" -icon info -message "User interaction required" -detail "The next step of installation will require the user to confirm Xcode command line tools installation.\n\nThis is required to install the C++ compiler and development tools."
	waitbox .wait "Installing..." "Installing Xcode command line tools.\n\nAn internet connection is required.\n\nIt may take a while, please wait..." "1. if required, allow the Terminal access\n2. click on 'Install'\n3. agree with the license agreement\n4. wait for the download\n5. click on 'Done'" 0 ""
	set res [ catch { exec xcode-select --install } result ]
	destroytop .wait
	if { $res } {
		ttk::messageBox -parent "" -type ok -title Error -icon error -message "Error installing Xcode" -detail "The installation of Xcode command line tools failed ($result).\n\nYou may try to repeat the installation or do a manual install following the steps described in 'Readme.txt'."
		lappend issues "Xcode Command Line tools missing (xcode-select --install)"
	}
}


#
# install Windows/macOS Gnuplot/MultiTail if required
#

if { ! [ string equal $CurPlatform linux ] && ( [ info exists gnuplot ] || [ info exists multitail ] ) } {

	if [ string equal $CurPlatform windows ] {
	
		if { ! $wadmin } {
			ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Cannot install Gnuplot" -detail "Installing without administrator rights prevents installing Gnuplot.\n\nPlease download Gnuplot at http://www.gnuplot.info and install it manually."
			lappend issues "Windows Gnuplot not installed (no admin rights)"
		} else {
			set res [ catch { set f [ open $filesDir/installer/wgnuplot.txt ] } result ]

			if { $res } {
				ttk::messageBox -parent "" -type ok -title Error -icon error -message "Error installing Gnuplot" -detail "Cannot open 'wgnuplot.txt' ($result).\n\nLSD installer is damaged."
				lappend issues "Windows Gnuplot not installed (no wgnuplot.txt)"
			} else {

				set res [ catch { string trim [ gets $f winGnuplot ] } result ]

				if { $res || ! [ file exists $filesDir/installer/$winGnuplot ] } {
					ttk::messageBox -parent "" -type ok -title Error -icon error -message "Error installing Gnuplot" -detail "Invalid content in 'wgnuplot.txt' ($result).\n\nLSD installer is damaged."
					lappend issues "Windows Gnuplot not installed (invalid wgnuplot.txt)"
				} else {

					set res [ catch { exec $filesDir/installer/$winGnuplot /SILENT /LOADINF=wgnuplot.inf } result ]

					if { $res } {
						ttk::messageBox -parent "" -type ok -title Error -icon error -message "Error installing Gnuplot" -detail "The installation of Gnuplot graphical terminal failed ($result).\n\nYou may try to repeat the installation or do a manual install following the steps described in 'Readme.txt'."
						lappend issues "Windows Gnuplot not installed ($winGnuplot)"
					}
				}

				close $f
			}
		}
	}

	if [ string equal $CurPlatform mac ] {
		# check if Homebrew is installed and install if not
		set res 0
		if [ catch { exec which brew } ] {
			set brewInsta "/bin/bash -c \\\"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\\\"; "
			set brewInstr "Homebrew package manager, "
			set brewSteps "in Terminal type your password and press <Return> twice\n3. "
			set brewMsg1 "Homebrew, "
			set brewMsg2 "\\nType your password and press <Return> twice:"
		} else {
			set brewInsta ""
			set brewInstr ""
			set brewSteps ""
			set brewMsg1 ""
			set brewMsg2 ""
		}

		if { [ info exists gnuplot ] && [ info exists multitail ] } {
			set pkgInsta "brew install multitail gnuplot; "
		} elseif { [ info exists gnuplot ] } {
			set pkgInsta "brew install gnuplot; "
		} else {
			set pkgInsta "brew install multitail; "
		}

		ttk::messageBox -parent "" -type ok -title "Tools Installation" -icon info -message "User interaction required" -detail "The next step of installation will require the user to confirm installation of ${brewInstr}Gnuplot graphical terminal and/or MultiTail tool.\n\nA Terminal window will open and the interaction must be performed there."
		set wait [ waitbox .wait "Installing..." "Installing ${brewInstr} Gnuplot graphical terminal\nand/or MultiTail tool.\nAn internet connection is required.\n\nIt may take a while, please wait..." "1. if required, allow the Terminal access\n2. ${brewSteps}Terminal window will close/disable when done\n" 1 "" ]

		set scpt [ open "$env(TMPDIR)/install_homebrew.as" w ]
		puts $scpt "tell application \"Terminal\""
		set openMsg "clear; echo \\\"Installing ${brewMsg1}Gnuplot and/or MultiTail\\nPlease wait for this window to close/deactivate automatically.${brewMsg2}\\\"; "
		set closeMsg "${pkgInsta}touch \$TMPDIR/brew-done.tmp; exit"
		puts $scpt "\tdo script \"${openMsg}${brewInsta}${closeMsg}\""
		puts $scpt "end tell"
		close $scpt
		exec chmod +x "$env(TMPDIR)/install_homebrew.as"

		file delete -force "$env(TMPDIR)/brew-done.tmp"
		set res [ catch { exec osascript "$env(TMPDIR)/install_homebrew.as" } ]

		if { ! $res } {
			set timeout 1800
			set elapsed 0
			while { ! [ file exists "$env(TMPDIR)/brew-done.tmp" ] && $elapsed < $timeout } {
				$wait configure -text [ format "%02d:%02d" [ expr { int( $elapsed / 60 ) } ] [ expr { $elapsed % 60 } ] ]
				update
				after 1000
				incr elapsed
			}

			if { $elapsed >= $timeout } {
				set res 1
				set result timeout
			}

		} else {
			set result $res
		}

		file delete -force "$env(TMPDIR)/install_homebrew.as" "$env(TMPDIR)/brew-done.tmp"
		destroytop .wait

		if { $res } {
			ttk::messageBox -parent "" -type ok -title Error -icon error -message "Error installing Gnuplot" -detail "The installation of Gnuplot graphical terminal (and/or other associated tools) failed ($result).\n\nYou may try to repeat the installation or do a manual install following the steps described in 'Readme.txt'."
			if { $brewInsta != "" } {
				lappend issues "Homebrew not installed ($brewInsta)"
			}
			lappend issues "Gnuplot not installed (brew gnuplot)"
			lappend issues "MultiTail not installed (brew multitail)"
		}
	}
}


#
# install Linux missing packages, if any
#

if { [ string equal $CurPlatform linux ] && [ llength $linuxPkgMiss ] > 0 } {

	# detect the package manager in use
	set found 0
	foreach pm [ array names linuxPmCmd ] {
		if { ! [ catch { exec which [ lindex $linuxPmCmd($pm) 0 ] } ] } {
			set found 1
			break
		}
	}

	if { ! $found } {
		ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Cannot install required packages" -detail "The detection of the computer package manager failed and LSD cannot install the missing required packages.\n\nPlease check your distribution documentation on how to install the following missing packages:\n\n$linuxPkgMiss"
		lappend issues "$linuxPkgMiss missing (unknown command)"

	} else {

		set lpack [ list ]
		foreach pack $linuxPkgMiss {

			set i [ lsearch -exact $linuxPkg $pack ]
			lappend lpack [ lindex $linuxPmPkg($pm) $i ]
		}

		ttk::messageBox -parent "" -type ok -title "Package Installation" -icon info -message "User interaction required" -detail "The next step of installation will try to install missing required packages. The user must confirm the installation.\n\nPlease use the same terminal window where this installer was launched. Do not close or interrupt it before installation is complete."
		set wait [ waitbox .wait "Installing..." "Installing packages\n${lpack}.\n\nAn internet connection is required.\n\nIt may take a while, please wait..." "1. go to the installer terminal window\n2. enter your password if asked\n3. confirm installation if required" 1 "" ]

		set scpt [ open "/tmp/install_packages.sh" w ]
		puts $scpt "#!/bin/bash"
		puts $scpt "clear"
		puts $scpt "echo \"Installing required packages\""
		puts $scpt "echo \"Please wait for the installation to complete\""
		puts $scpt "sudo $linuxPmCmd($pm) $lpack"
		puts $scpt "if \[ \"\$\?\" == \"0\" \]; then"
		puts $scpt "	echo Installation completed"
		puts $scpt "	touch /tmp/pack-install-done.tmp"
		puts $scpt "else"
		puts $scpt "	echo Installation failed"
		puts $scpt "	touch /tmp/pack-install-fail.tmp"
		puts $scpt "fi"
		puts $scpt "exit"
		close $scpt
		exec chmod +x "/tmp/install_packages.sh"

		file delete -force "/tmp/pack-install-done.tmp" "/tmp/pack-install-fail.tmp"
		set res [ catch { exec /bin/bash -c /tmp/install_packages.sh & } result ]

		if { ! $res } {
			set timeout 1800
			set elapsed 0
			while { ! [ file exists "/tmp/pack-install-done.tmp" ] && ! [ file exists "/tmp/pack-install-fail.tmp" ] && $elapsed < $timeout } {
				$wait configure -text [ format "%02d:%02d" [ expr { int( $elapsed / 60 ) } ] [ expr { $elapsed % 60 } ] ]
				update
				after 1000
				incr elapsed
			}

			if [ file exists "/tmp/pack-install-fail.tmp" ] {
				set res 1
				set result "command failed"
			}
			if { $elapsed >= $timeout } {
				set res 1
				set result "command timeout"
			}

		} else {
			set result $res
		}

		file delete -force "/tmp/install_packages.sh" "/tmp/pack-install-done.tmp" "/tmp/pack-install-fail.tmp"
		destroytop .wait

		if { $res } {
			ttk::messageBox -parent "" -type ok -title Error -icon error -message "Error installing packages" -detail "The installation of required packages failed ($result).\n\nYou may try to repeat the installation or do a manual install following the steps described in 'Readme.txt'."
			lappend issues "$linuxPkgMiss missing (sudo $linuxPmCmd($pm) $lpack)"
		}
	}
}


#
# update header/lib paths in Linux
#

if [ string equal $CurPlatform linux ] {

	if { [ llength $pathInclude ] > 1 || [ llength $pathLib ] > 1 } {
		ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Complex include/lib paths" -detail "Your computer has a complex setup of multiple include and lib file paths which cannot be configured automatically.\n\nYou may have to manually adjust the correct paths to the include/lib files in LSD System Options menu and in '$linuxMkFile' before compiling LMM."
		lappend issues "include/lib paths not configured (nano $linuxMkFile)"
	}

	# update include/libs paths in makefile-linux and system_options-linux.txt
	set mkFile [ open "$RootLsd/$LsdSrc/$linuxMkFile" r ]
	set soFile [ open "$RootLsd/$LsdSrc/$linuxOptFile" r ]
	set mk [ read $mkFile ]
	set so [ read $soFile ]
	close $mkFile
	close $soFile

	if { [ llength $pathInclude ] > 0 } {
		set mk [ sed "s|[ lindex $linuxInclude 0 ]|[ lindex $pathInclude 0 ]" $mk ]
		set so [ sed "s|[ lindex $linuxInclude 0 ]|[ lindex $pathInclude 0 ]" $so]
	}

	if { [ llength $pathLib ] > 0 } {
		set mk [ sed "s|[ lindex $linuxLib 0 ]|[ lindex $pathLib 0 ]" $mk ]
		set so [ sed "s|[ lindex $linuxLib 0 ]|[ lindex $pathLib 0 ]" $so ]
	}

	set mkFile [ open "$RootLsd/$LsdSrc/$linuxMkFile" w ]
	set soFile [ open "$RootLsd/$LsdSrc/$linuxOptFile" w ]
	puts -nonewline $mkFile $mk
	puts -nonewline $soFile $so
	close $mkFile
	close $soFile
}


#
# recompile LMM in Linux if not default distro
#

if [ string equal $CurPlatform linux ] {

	# detect the package manager in use
	set found 0
	foreach pm [ array names linuxPmCmd ] {
		if { ! [ catch { exec which [ lindex $linuxPmCmd($pm) 0 ] } ] } {
			set found 1
			break
		}
	}

	if { ! $found } {
		ttk::messageBox -parent "" -type ok -title Warning -icon warning -message "Cannot recompile LMM" -detail "The detection of Linux distribution failed and LSD Model Manager (LMM) was not recompiled for your computer.\n\nYou may try to use the installed precompiled LMM or do a manual compilation following the steps described in 'Readme.txt'.\nYou may have to adjust the paths to the include/lib files in '$linuxMkFile'."
		lappend issues "Cannot recompile LMM (make -f $linuxMkFile)"

	} elseif { ! [ string equal $pm $linuxDefPm ] } {

		waitbox .wait "Compiling LMM..." "Compiling LSD Model Manager (LMM)\nfor your Linux distribution.\n\nPlease wait..." "" 0 ""

		file copy -force "$RootLsd/LMM" "/tmp/"
		cd "$RootLsd/$LsdSrc"

		set res [ catch { exec make -f makefile.LMM } result ]

		file delete -force {*}[ glob -nocomplain -directory "$RootLsd/$LsdSrc" *.o ]
		destroytop .wait

		if { $res } {
			ttk::messageBox -parent "" -type ok -title Error -icon error -message "Error compiling LMM" -detail "The compilation of LSD Model Manager (LMM) failed ($result).\n\nYou may try to do a manual compilation following the steps described in 'Readme.txt' and also may have to."
			lappend issues "Cannot recompile LMM (make -f $linuxMkFile)"
			file copy -force "/tmp/LMM" "/$RootLsd/"
		} else {
			file delete -force "/tmp/LMM"
		}
	}
}


#
# finish installation
#

destroy .dir .b

ttk::frame .end

if { [ llength $issues ] == 0 } {
	ttk::label .end.msg1 -text "LSD installation completed successfully."
} else {
	ttk::label .end.msg1 -justify center -text "LSD installation completed\nwith warnings, some issues remain.\n\nYou may try to repeat the installation or do a manual\ninstall following the steps described in 'Readme.txt'."

	catch {
		set f [ open "$RootLsd/installer.err" a ]
		puts $f ""
		puts $f "====================> [ clock format [ clock seconds ] -format "%Y-%m-%d %H:%M:%S" ]"
		puts $f "LSD Installer completed with errors."
		puts $f "The installation directory is '$RootLsd'."
		puts $f "Please check 'Readme.txt' for instructions on"
		puts $f "how to solve the issues before using LSD."
		puts $f ""
		puts $f "Issue (failed command line operation):"

		foreach issue $issues {
			puts $f ". $issue"
		}

		close $f
	}
}

ttk::label .end.msg2 -text "LSD/LMM can be run using the created desktop icon,\nor using the computer's program menu."  -justify center
ttk::label .end.msg3 -text "The installation directory is '$RootLsd'"
pack .end.msg1 .end.msg2 .end.msg3 -pady 5

if { [ llength $issues ] > 0 } {

	ttk::label .end.err1 -text "The pending issues are:"

	ttk::frame .end.err2
	set i 1
	foreach issue $issues {
		ttk::label .end.err2.t$i -style hl.TLabel -text ". $issue"
		pack .end.err2.t$i
		incr i
	}

	ttk::label .end.err3 -justify center -text "Please try to solve the issues before using LSD.\nThis list is saved in 'installer.err'"
	pack .end.err1 .end.err2 .end.err3 -pady 5
}

pack .end -padx 10 -pady 10

ttk::frame .b
ttk::button .b.finish -width $butWid -text Finish -command { set done 2 }
bind .b.finish <Return> { .b.finish invoke }
bind . <Escape> { .b.finish invoke }
tooltip::tooltip .b.finish "Close LSD installer"

if { [ llength $issues ] == 0 && ( ! [ info exists sysPath ] || ! $sysPath ) } {
	ttk::button .b.run -width $butWid -text "Run Now" -command { set done 1 }
	bind .b.run <Return> { .b.run invoke }
	pack .b.run .b.finish -padx 10 -pady 10 -side left
	focus .b.run
	tooltip::tooltip .b.run "Close installer and launch LSD"
} else {
	pack .b.finish -padx 10 -pady 10 -side left
	focus .b.finish
}

pack .b -side right

settop . "LSD Installer" { set done 2 } "" yes

set done 0
tkwait variable done


#
# open LMM if asked
#

if { $done == 1 } {
	if [ string equal $CurPlatform windows ] {
		catch { exec $RootLsd/LMM.exe & }
	} elseif [ string equal $CurPlatform linux ] {
		catch { exec $RootLsd/LMM & }
	} else {
		catch { exec open -F -n $RootLsd/LMM.app & }
	}
}

exit 0
