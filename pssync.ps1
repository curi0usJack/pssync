<#
.SYNOPSIS
	Synchronizes powershell modules with participating team members.
	
.DESCRIPTION
	In order to have your scripts synchronized and made available for others to use, you must include a comment in your script
	that matches the following format - #PSSYNCVERSION:1. The number following the colon is the version number (minor versions, for example, '1.1', are supported). If you have changes
	that you have made and want them to be propogated to synchronization partners - simply increment the version number and resync.
	All synchronization partners will get the updated version the next time they perform a synchronization. 
.PARAMETER
.EXAMPLE
.NOTES
	version			1.1
	last modified 		12/27/13
	author			curi0usJack
				https://twitter.com/curi0usJack
				https://project500.squarespace.com/journal/2013/12/27/powershell-lan-shared-repository
	
	Workflow:
		1) Get the local scripts to be synchronized and their versions.
		2) Get the remote repository scripts and their versions.
		3) Synchronize the two repositories.
			a) Make a backup of any scripts to be overwritten. Backups are made to $remotearchivedir
			b) Overwrite both local & remote scripts with higher versions.
#>
$localmoduledir = "$env:psmodulepath".Split(';')[0]
$remotemoduledir = "\\someserver\someshare$\Modules"
$remotearchivedir = "\\someserver\someshare$\Archive"
$processedfiles = @()


# The following blocks loop through the remote and local module directories looking for module files that contain the PSSYNCVERSION string to determine what needs to be synchronized.
$remotemodules = 	gci $remotemoduledir -Recurse -Include *.psm1 | 
					select `
						@{n='DirectoryName';e={$_.DirectoryName}},
						@{n='FileName';e={$_.Name}},
						@{n='Version';e={gc $_ | Select-String "PSSYNCVERSION" | %{$_.Line.Split(":")[1] -as [decimal]}}} |
					where {$_.Version -ne $null}
						
					
$localmodules = 	gci $localmoduledir -Recurse -Include *.psm1 | 
					select `
						@{n='DirectoryName';e={$_.DirectoryName}},
						@{n='FileName';e={$_.Name}},
						@{n='Version';e={gc $_ | Select-String "PSSYNCVERSION" | %{$_.Line.Split(":")[1] -as [decimal]}}} |
					where {$_.Version -ne $null}

# This function simply creates a new module folder (locally) and copies the module to it.
function CopyNewModule($sourcepath) {
	$filename = $sourcepath.Substring($sourcepath.LastIndexOf('\') + 1, $sourcepath.Length - $sourcepath.LastIndexOf('\') -1)
	$newfoldername = $filename.Split('.')[0]
	$newfilepath = "$localmoduledir\\$newfoldername"
	
	# Create the new folder & copy the file
	try {
		[System.IO.Directory]::CreateDirectory($newfilepath)
		[System.IO.File]::Copy($sourcepath, $newfilepath)
	}
	catch { $Error[0].Exception.Message }
}

#Generate a single comparision collection
function HarmonizeCollections($remotemods, $localmods) {
	# RemoteMods is authority. Get all local matching
	$returnobjs = @()
	if (($remotemods | measure).Count -gt 0) {
		foreach ($remotemod in $remotemods) {
			$localversion = $localmods | ?{$_.FileName -eq $remotemod.FileName} | select -ExpandProperty Version
			if ($localversion -eq $null) {$localversion = -1}
			
			$foldername = $remotemod.FileName.Replace(".psm1","")
			$returnobjs += New-Object -TypeName PSObject -Property @{
				FileName = $remotemod.FileName
				FolderName = $foldername
				RemoteDirectoryName = $remotemoduledir + "\" + $foldername
				LocalDirectoryName = $localmoduledir + "\" + $foldername
				RemoteVersion = $remotemod.Version
				LocalVersion = $localversion
			}
		}
	}
	# Get all local matching if they have not already been added to the collection. 
	if (($localmods | measure).Count -gt 0) {
		foreach ($localmod in $localmods) {
			# if the local file has not already been added to the collection, add it - otherwise all local files
			# were accounted for in the previous foreach statement.
			if (($returnobjs | ?{$_.FileName -eq $localmod.FileName}) -eq $null) {
				$remoteversion = $remotemods | ?{$_.FileName -eq $localmod.FileName} | select -ExpandProperty Version
				if ($remoteversion -eq $null) {$remoteversion = -1}
				
				$foldername = $localmod.FileName.Replace(".psm1","")
				$returnobjs += New-Object -TypeName PSObject -Property @{
					FileName = $localmod.FileName
					FolderName = $foldername
					RemoteDirectoryName = $remotemoduledir + "\" + $foldername
					LocalDirectoryName = $localmoduledir + "\" + $foldername
					RemoteVersion = $remoteversion
					LocalVersion = $localmod.Version
				}
			}
		}
	}
	return $returnobjs
}

function CheckDir($path) {
	if (![System.IO.Directory]::Exists($path)) {
		[System.IO.Directory]::CreateDirectory($path) | Out-Null
	}
}

# This function will will make a backup of the existing module on the server in case it needs to be restored for any reason.
function ArchiveFile($remotedir,$filename,$currentversion) {
	$remotepath = $remotedir + "\" + $filename
	# 1. Make sure the folder we're being asked to archive actually exists
	if ([System.IO.File]::Exists($remotepath)) {
		# 2. Get the create the destination path
		$destfoldername = $remotearchivedir + "\" + $filename.Replace(".psm1", "")
		$destfilename = $destfoldername + "\" + $filename.Replace(".psm1", "-v" + $currentversion + ".psm1")
		# 3. Make sure the destination archive directory exists
		CheckDir $destfoldername
		# 4. Copy the file
		[System.IO.File]::Copy($remotepath, $destfilename, "true")
	}
}


$maincol = @()
$maincol = HarmonizeCollections $remotemodules $localmodules
$maincolcount = ($maincol | measure).Count
$workingcount = 1

if ($maincolcount -gt 0) {
	foreach ($script in $maincol) {
		Write-Progress -Activity "Synchronizing Scripts" -Status $script.FileName -PercentComplete ($workingcount / $maincolcount * 100)
		
		$remotepath = $script.RemoteDirectoryName + "\" + $script.FileName
		$localpath = $script.LocalDirectoryname + "\" + $script.FileName
		if ($script.RemoteVersion -gt $script.LocalVersion) {
			# If the target local directory doesn't exist, create it
			CheckDir $script.LocalDirectoryName
			# Then copy the target remote file to the local directory
			[System.IO.File]::Copy($remotepath, $localpath, "true")
		}
		elseif ($script.LocalVersion -gt $script.RemoteVersion) {
			# 1. Make a backup of the existing script (if it already exists)
			ArchiveFile $script.RemoteDirectoryName $script.FileName $script.RemoteVersion
			# 2. Make sure the folder exists
			CheckDir $script.RemoteDirectoryName
			# 3. Copy the target local file to the remote directory
			[System.IO.File]::Copy($localpath, $remotepath, "true")
		}
		$workingcount++
	}
}
