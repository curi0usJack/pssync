#PowerShell Module Synchronization Repository
###pssync.ps1

__PSSync__ is a simple powershell script that performs two way synchronization between the powershell modules on your machine and a central repository on a server. It works by looking for a version statement in any powershell module you wish to synchronize and performing synchronization if that statement is found. If the version statement is found, it will copy the module to the repository. Anyone who then runs pssync will receive a copy. Note this currently only supports powershell Modules (.psm1 files)

Important to restate that this is really meant for a corporate or shared environment. This uses SMB connections, and will not work across the internet.

####Pre-Requisites

1)	Hopefully you are a network admin (or are good friends with one <grin>). Have a network share setup and get modify rights to it. Assume \\someserver\someshare$.

2)	Create the following directories: 'Modules', 'Archive', and 'PSSYNC'. Add pssync.ps1 to the PSSYNC directory.

3)	I *strongly* recommend using NTFS perms to restrict access to these directories, otherwise it's possible that anyone will be able to access your scripts. Here are the best practices
	regarding NTFS perms:
	
		-> Modules Directory:	Authorized Users (insert proper Active Directory groups here) get Modify rights.
		
		-> Archive Directory:	Authorized Users get Read & Write access, but not Delete!. You don't want users to delete your backups!
		
		-> PSSYNC Directory:	Authorized Users get Read access only to this directory.
		
4) Modify the $remotemoduledir and $remotearchivedir variables in pssync.ps1 to reflect the UNC paths of the directories you setup in step #2 above.


####How-To's

	- Setup your machine for pssync
	
		1)	Get Adminrights to your machine.
		2)	Ensure that you have a local powershell profile. The file is %USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1. If it doesn’t exist, create it.
		3) 	Add the following two lines to the profile:
			set-alias pssync "\\someserver\someshare$\PSSync\pssync.ps1"
			pssync
		4) 	Note, the last line is optional. Add it if you want to synchronize scripts every time you open powershell. If you want to sync on command, remove that line, and just type “pssync” from a powershell prompt whenever you wish to sync.
		
	- Adding a module to the repository.
		Any modules that people want to sync must meet the following criteria:
			a)	They must be in a directory that is named after the module. For instance, if a module named MyModule, then it must be in the following path: %USERPROFILE%\Documents\WindowsPowerShell\MyModule\MyModule.psm1. This is non-negotiable.
			b)	Somewhere in the psm1 file, they must contain a comment that looks like the following:
				# PSSYNCVERSION:1 (where "1" is the version number)

		1)	Open the module and add the following line (as a comment) anywhere in your script:
			# PSSYNCVERSION:1
			In this case “1” is the version number, but it can be any positive number you want, even decimals (1.0).
		2)	Open powershell, type pssync.
		3)	Done – the module is now in the repository (assuming you got no errors).
		
	- Retrieving a module from the repository
		1)	If someone else adds a module and you want it right away, just launch powershell and type pssync (or, just launch powershell if you kept the code in your profile as is from the step above). You should then be able to run Get-Modules –ListAvailable and see their module.
		2)	If you load a module, someone makes a change, and you want to update yours using pssync, best to close your existing powershell window & reopen it. Or, if you prefer, you can always unload the module from the current session & reload it after running pssync.
		
	- Updating a module
		Say you need to make some changes and need those changes to be synced up to the repository, do the following:
		1)	Make your changes
		2)	Increment the version number. That is, change PSSYNCVERSION:1.0 to PSSYNCVERSION:1.1.
		3)	From a powershell line, run pssync.
		4)	Done. Once everyone else syncs, they will have the new version.
		5)	No worries about overwriting. Every version of a script is backed up and archived to the archive directory configured in pssync. Any version can be recovered at any time simply
			by copying it locally from the Archive directory, incrementing the version, and running pssync
			
	- Don’t want my module synced anymore
		1)	Just take out the version statement from the module. No future changes will be propagated, and no changes anyone else makes will overwrite your copy. That said, everyone will still have a copy of the last module that was synced (until someone overwrites it)


That's it! Hopefully you find it easy enough to use. Feedback is always welcome, [@curi0usJack](https://twitter.com/curi0usJack)
