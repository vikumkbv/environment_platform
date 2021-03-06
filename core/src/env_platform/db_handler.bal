import ballerina/config as conf;
import ballerina/log;
import ballerina/mongodb;


// Mongodb configurations.
mongodb:ClientConfig mongoConfig = {
    host: conf:getAsString("DB_HOST"),
    username: conf:getAsString("DB_USER_NAME"),
    password: conf:getAsString("DB_PASSWORD"),
    options: {sslEnabled: false, serverSelectionTimeout: 500}
};
mongodb:Client mongoClient = check new (mongoConfig);
mongodb:Database mongoDatabase = check mongoClient->getDatabase("EnvironmentPlatform");
mongodb:Collection applicationCollection = check mongoDatabase->getCollection("applications");

# The `saveApplication` function will save the application to the applications collection in the database.
# 
# + form - Form containing the tree removal data.
# + return - Returns true if the application is saved, error if there is a mongodb:DatabaseError.
function saveApplication(TreeRemovalForm form) returns boolean|error {

    // Construct the application.
    map<json> application = {
        "applicationId": "tcf-20200513",
        "status": form.status,
        "numberOfVersions": 1,
        "versions": [
                {
                    "title": form.title,
                    "applicationCreatedDate": {
                        "year": form.applicationCreatedDate.year,
                        "month": form.applicationCreatedDate.month,
                        "day": form.applicationCreatedDate.day,
                        "hour": form.applicationCreatedDate.hour,
                        "minute": form.applicationCreatedDate.minute
                    },
                    "removalDate": {
                        "year": form.removalDate.year,
                        "month": form.removalDate.month,
                        "day": form.removalDate.day,
                        "hour": form.removalDate.hour,
                        "minute": form.removalDate.minute
                    },
                    "reason": form.reason,
                    "applicationType": form.applicationType,
                    "requestedBy": form.requestedBy,
                    "permitRequired": form.permitRequired,
                    "landOwner": form.landOwner,
                    "treeRemovalAuthority": form.treeRemovalAuthority,
                    "city": form.city,
                    "district": form.district,
                    "nameOfTheLand": form.nameOfTheLand,
                    "planNumber": form.planNumber,
                    "area": extractAreaAsJSONArray(form.area),
                    "treeInformation": extractTreeInformationAsJSONArray(form.treeInformation)
                }
            ]
    };
    log:printDebug("Constructed application: " + application.toString());

    mongodb:DatabaseError? inserted = applicationCollection->insert(application);

    if (inserted is mongodb:DatabaseError) {
        log:printDebug("An error occurred while saving the application with ID: " + application.applicationId + ". " + inserted.reason() + ".") ;
    } else {
        log:printDebug("Application with application ID: " + application.applicationId + " was saved successfully.");
    }
    return inserted is mongodb:DatabaseError ? inserted : true;
}

# The `deleteApplication` function will delete application drafts with the status "draft".
# 
# + applicationId - The Id of the application to be deleted.
# + return - Returns true if the application is deleted, false if not or else returns mongodb:DatabaseError
# array index out of bound if there are no applications with the specific application Id.
function deleteApplication(string applicationId) returns boolean|error {

    string applicationStatus = check getApplicationStatusByApplicationId(applicationId);
    if (applicationStatus == "draft") {
        int|error deleted = applicationCollection->delete({"applicationId": applicationId, "status": "draft"});
        if (deleted is int) {
            log:printDebug("Deleted application count: " + deleted.toString());
            return deleted == 1 ? true : false;
        } else {
            // Returns the error.
            log:printDebug("An error occurred while deleting the draft with the application ID: " + applicationId + ". " + deleted.reason() + ".");
            return deleted;
        }
    } else {
        log:printDebug("Cannot delete the application with application ID: " + applicationId + " since it is already submitted.");
        return error("Invalid Operation", message = "Cannot delete the application with the appilcation ID: "
            + applicationId + " since it is already submitted.");
    }
}

# The `getApplicationStatusByApplicationId` function will return the status of the application(draft or submitted).
# 
# + applicationId - The Id of the application which the status should be found for.
# + return - Returns the status of the application(draft, submitted).
function getApplicationStatusByApplicationId(string applicationId) returns string|error {

    // Get the application with application Id.
    map<json>[] find = check applicationCollection->find({"applicationId": applicationId});
    map<json>|error application = trap find[0];
    if (application is map<json>) {
        log:printDebug("Status of the application with application ID: " + applicationId + " is " + application.status.toString() + ".");
        return trap <string>application.status;
    } else {
        log:printDebug("An error occurred while retrieving the application:  " + application.toString() + ".");
        return application;
    }
}

# The `updateApplicationDraft` function will alter the exsisting application draft with the incoming form details.
# 
# + form - Form containing the tree removal data.
# + return - This function will return true if draft is updated in the database, false if not or else it returns a mongodb:Database error.
function updateApplicationDraft(TreeRemovalForm form, string applicationId) returns boolean|error {

    map<json> application = {
        "title": form.title,
        "applicationCreatedDate": {
            "year": form.applicationCreatedDate.year,
            "month": form.applicationCreatedDate.month,
            "day": form.applicationCreatedDate.day,
            "hour": form.applicationCreatedDate.hour,
            "minute": form.applicationCreatedDate.minute
        },
        "removalDate": {
            "year": form.removalDate.year,
            "month": form.removalDate.month,
            "day": form.removalDate.day,
            "hour": form.removalDate.hour,
            "minute": form.removalDate.minute
        },
        "reason": form.reason,
        "applicationType": form.applicationType,
        "requestedBy": form.requestedBy,
        "permitRequired": form.permitRequired,
        "landOwner": form.landOwner,
        "treeRemovalAuthority": form.treeRemovalAuthority,
        "city": form.city,
        "district": form.district,
        "nameOfTheLand": form.nameOfTheLand,
        "planNumber": form.planNumber,
        "area": extractAreaAsJSONArray(form.area),
        "treeInformation": extractTreeInformationAsJSONArray(form.treeInformation)
    };
    log:printDebug("Constructed application: " + application.toString());

    int|mongodb:DatabaseError updated = applicationCollection->update({"versions.0": application}, {"applicationId": applicationId});

    if (updated is int) {
        log:printDebug("Updated status for application with application ID: " + applicationId + " is " + updated.toString() + ".");
        return updated == 1 ? true : false;
    } else {
        log:printDebug("An error occurred while updating the draft application with the application ID: " + applicationId + ". " + updated.reason() + ".");
        return updated;
    }
}
