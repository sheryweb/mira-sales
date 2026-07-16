@RestResource(urlMapping='/UnitFile/*')
global without sharing class UnitFileServiceController {

    @HttpGet
    global static FileResponseWrapper getFileContent() {
        FileResponseWrapper response = new FileResponseWrapper();

        try {
            String unitId = RestContext.request.params.get('unitId');

            // Validate the UnitId parameter
            if (String.isBlank(unitId)) {
                response.success = false;
                response.message = 'UnitId parameter is required';
                return response;
            }

            // Query the File__c object
            List<File__c> files = [
                SELECT Id, Name, Type__c, Unit__c
                FROM File__c
                WHERE Unit__c = :unitId
                AND Type__c IN ('Unit Layout Preview', 'Floor Plan')
            ];

            // Debug: Log the files found
            System.debug('Files found for UnitId ' + unitId + ': ' + files.size());
            for (File__c file : files) {
                System.debug('File: ' + file.Name + ', Type: ' + file.Type__c);
            }

            if (files.isEmpty()) {
                response.success = false;
                response.message = 'No files found for the specified unit and types';
                return response;
            }

            // Get all ContentDocumentIds for all files
            Set<Id> contentDocIds = new Set<Id>();
            for (File__c file : files) {
                List<ContentDocumentLink> fileLinks = [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :file.Id
                ];
                for (ContentDocumentLink link : fileLinks) {
                    contentDocIds.add(link.ContentDocumentId);
                }
            }

            if (contentDocIds.isEmpty()) {
                response.success = false;
                response.message = 'No content documents linked to these files';
                return response;
            }

            // Get ALL ContentVersions for these content documents
            List<ContentVersion> versions = [
                SELECT Id, Title, FileType, FileExtension, ContentSize, VersionData, ContentDocumentId, VersionNumber
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                ORDER BY ContentDocumentId, VersionNumber DESC
            ];

            if (versions.isEmpty()) {
                response.success = false;
                response.message = 'No content versions found for these documents';
                return response;
            }

            // Create separate lists for floor plans and unit layouts
            List<FileData> floorPlansList = new List<FileData>();
            List<FileData> unitLayoutsList = new List<FileData>();
            
            // Process each file record directly instead of going through ContentDocumentLinks
            for (File__c fileRecord : files) {
                System.debug('Processing file record: ' + fileRecord.Name + ', Type: ' + fileRecord.Type__c);
                
                // Get ContentDocumentLinks for this specific file
                List<ContentDocumentLink> fileLinks = [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :fileRecord.Id
                ];
                
                if (!fileLinks.isEmpty()) {
                    // Get the latest version for this file's content document
                    ContentVersion latestVersion = null;
                    for (ContentVersion version : versions) {
                        if (version.ContentDocumentId == fileLinks[0].ContentDocumentId) {
                            if (latestVersion == null || version.VersionNumber > latestVersion.VersionNumber) {
                                latestVersion = version;
                            }
                        }
                    }
                    
                    if (latestVersion != null) {
                        FileData fileData = new FileData();
                        fileData.fileId = fileRecord.Id;
                        fileData.fileName = latestVersion.Title;
                        fileData.fileType = latestVersion.FileType;
                        fileData.fileExtension = latestVersion.FileExtension;
                        fileData.contentSize = latestVersion.ContentSize;
                        fileData.fileContent = EncodingUtil.base64Encode(latestVersion.VersionData);
                        fileData.type = fileRecord.Type__c;
                        
                        // Separate files by type
                        System.debug('Adding file: ' + fileRecord.Name + ', Type: ' + fileRecord.Type__c);
                        if (fileRecord.Type__c == 'Floor Plan') {
                            floorPlansList.add(fileData);
                            System.debug('Added to floorPlansList. Count: ' + floorPlansList.size());
                        } else if (fileRecord.Type__c == 'Unit Layout Preview') {
                            unitLayoutsList.add(fileData);
                            System.debug('Added to unitLayoutsList. Count: ' + unitLayoutsList.size());
                        } else {
                            System.debug('File type not recognized: ' + fileRecord.Type__c);
                        }
                    } else {
                        System.debug('No content version found for file: ' + fileRecord.Name);
                    }
                } else {
                    System.debug('No content document links found for file: ' + fileRecord.Name);
                }
            }

            // Populate the response
            response.success = true;
            response.message = 'Files retrieved successfully';
            response.files.floorPlans = floorPlansList;
            response.files.unitLayouts = unitLayoutsList;

        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
        }

        return response;
    }

    global class FileResponseWrapper {
        global Boolean success { get; set; }
        global String message { get; set; }
        global FilesWrapper files { get; set; }

        global FileResponseWrapper() {
            this.success = false;
            this.message = '';
            this.files = new FilesWrapper();
        }
    }

    global class FilesWrapper {
        global List<FileData> floorPlans { get; set; }
        global List<FileData> unitLayouts { get; set; }

        global FilesWrapper() {
            this.floorPlans = new List<FileData>();
            this.unitLayouts = new List<FileData>();
        }
    }

    global class FileData {
        global String fileId { get; set; }
        global String fileName { get; set; }
        global String fileType { get; set; }
        global String fileExtension { get; set; }
        global Long contentSize { get; set; }
        global String fileContent { get; set; } // Base64 encoded blob
        global String type { get; set; } // File__c.Type__c field
    }
}