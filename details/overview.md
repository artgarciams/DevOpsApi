# Welcome to the Release Notes WiKi page generator.

By simply tagging builds in a release you can generate a comprehensive set of release notes. 

The system will generate the following lists:
1. Table of Contents with links to each section
2. List of all builds tagged
3. Details of each build tagged
4. Stages in each build tagged
5. All work items in each build tagged and a link to each work item
6. Changes associated with each build tagged and links to each change
	
## REQUIRED SETTINGS    
	In order for this extension to run you must set a few options in your organization.
	First, you will need to allow the scripts to access the OAuth token. This will allow the script 
	to be able to access the Azure DevOps Rest API's.
	
![settings](images/pipelineSettings.png)

   Next make sure the Organization settings are set. You will need to set 
   "Limit job authentication socpe to current project for non-release Pipelines" and 
   "Limit job authorization scope to reference Azure DevOps repos" 
   to ** Off ** as shown below.
   
![settings](images/ProjectSettings.png)

## RELEASE NOTES OPTIONS
	In order for the release notes to generate, you will need to fill in the following items shown below.
	1 - Work Items
		This is the work items you want to include in the Release Notes. If you include "User Story" 
		any child items checked into the build will be rolled up and you will only get the parent 
		item in the release notes.
	2 - Build Tags
		This is the Tag you want to search for in the builds.
	3 - Project WiKi	
		This is the WiKi you want to publish to.
	4 - WiKi Page Parent
		This is the parent page you want to use for your Release Notes. This extension requires a 
		seperate parent page to publish under in order to not step on any existing pages.
	5 - WiKi Page to Publish Release Notes into
		This si the name of the page you want your release notes.
	
	6 - WiKi Section Notes
		The inputs here are all optional. If you include something it will be displayed at the top of the section selected.
		This is to allow any special comments you want to include in those sections.
		
	7 - Permanent WiKI Notes Info
		This section will retain any notes you enter here from run to run. It will add this section to the beginning of the page 
		
		A - Permanent Notes Title
			This is the title you want for your permanent notes. Be advised, standard WiKi markup 
			language syntax applies. Any markup you add will be reflected.
		B - Permanent Notes
			This is any notes you want to add to the page and keep from run to run.Be advised, 
			standard WiKi markup language syntax applies. Any markup you add will be reflected.
	
![WiKi Input](images/ReleaseOptions.png)
	