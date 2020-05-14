import ballerina/config as conf;
import ballerina/mongodb;

// TODO - Add debug logs.

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

    mongodb:DatabaseError? inserted = applicationCollection->insert(application);

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
            return deleted == 1 ? true : false;
        } else {
            // Returns the error.
            return deleted;
        }
    } else {
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
        return trap <string>application.status;
    } else {
        return application;
    }
}