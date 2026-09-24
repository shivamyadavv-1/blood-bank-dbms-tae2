-- =========================================================
-- BLOOD BANK & BLOOD DONATION MANAGEMENT SYSTEM
-- TAE 2 - PostgreSQL 18
-- Schema aligned to the approved TAE-1 relational design.
-- =========================================================

DROP TABLE IF EXISTS BLOOD_ISSUE CASCADE;
DROP TABLE IF EXISTS REQUEST_DETAIL CASCADE;
DROP TABLE IF EXISTS BLOOD_REQUEST CASCADE;
DROP TABLE IF EXISTS BLOOD_INVENTORY CASCADE;
DROP TABLE IF EXISTS STORAGE_LOCATION CASCADE;
DROP TABLE IF EXISTS BLOOD_COMPONENT CASCADE;
DROP TABLE IF EXISTS BLOOD_SCREENING CASCADE;
DROP TABLE IF EXISTS BLOOD_UNIT CASCADE;
DROP TABLE IF EXISTS DONATION CASCADE;
DROP TABLE IF EXISTS HOSPITAL CASCADE;
DROP TABLE IF EXISTS DONOR CASCADE;
DROP TABLE IF EXISTS BLOOD_GROUP CASCADE;

CREATE TABLE BLOOD_GROUP (
    Blood_Group_ID INT PRIMARY KEY,
    ABO_Group CHAR(2) NOT NULL CHECK (ABO_Group IN ('A','B','AB','O')),
    Rh_Factor CHAR(1) NOT NULL CHECK (Rh_Factor IN ('+','-')),
    CONSTRAINT uq_blood_group UNIQUE (ABO_Group, Rh_Factor)
);

CREATE TABLE DONOR (
    Donor_ID VARCHAR(10) PRIMARY KEY,
    First_Name VARCHAR(50) NOT NULL,
    Last_Name VARCHAR(50) NOT NULL,
    Date_of_Birth DATE,
    Gender VARCHAR(10) CHECK (Gender IN ('Male','Female','Other')),
    Phone VARCHAR(15),
    Email VARCHAR(100) UNIQUE,
    Address VARCHAR(200)
);

CREATE TABLE DONATION (
    Donation_ID VARCHAR(10) PRIMARY KEY,
    Donor_ID VARCHAR(10) NOT NULL,
    Blood_Group_ID INT NOT NULL,
    Donation_Date DATE NOT NULL,
    Donation_Type VARCHAR(30) NOT NULL CHECK (Donation_Type IN ('Camp','Replacement','Voluntary')),
    Collection_Status VARCHAR(30) NOT NULL CHECK (Collection_Status IN ('Collected','Rejected','Processed')),
    CONSTRAINT fk_donation_donor FOREIGN KEY (Donor_ID) REFERENCES DONOR(Donor_ID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_donation_group FOREIGN KEY (Blood_Group_ID) REFERENCES BLOOD_GROUP(Blood_Group_ID) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE BLOOD_UNIT (
    Blood_Unit_ID VARCHAR(10) PRIMARY KEY,
    Donation_ID VARCHAR(10) NOT NULL,
    Collection_Date DATE,
    Volume_ml DECIMAL(6,2) CHECK (Volume_ml > 0),
    Expiry_Date DATE,
    Unit_Status VARCHAR(30) CHECK (Unit_Status IN ('Collected','Screening','Eligible','Rejected','Expired')),
    CONSTRAINT fk_unit_donation FOREIGN KEY (Donation_ID) REFERENCES DONATION(Donation_ID) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE BLOOD_SCREENING (
    Screening_ID VARCHAR(10) PRIMARY KEY,
    Blood_Unit_ID VARCHAR(10) NOT NULL,
    Screening_Date DATE NOT NULL,
    HIV_Result VARCHAR(30) CHECK (HIV_Result IN ('Non-Reactive','Reactive','Pending')),
    HBV_Result VARCHAR(30) CHECK (HBV_Result IN ('Non-Reactive','Reactive','Pending')),
    HCV_Result VARCHAR(30) CHECK (HCV_Result IN ('Non-Reactive','Reactive','Pending')),
    Syphilis_Result VARCHAR(30) CHECK (Syphilis_Result IN ('Non-Reactive','Reactive','Pending')),
    Overall_Result VARCHAR(30) CHECK (Overall_Result IN ('Eligible','Ineligible','Pending')),
    Screening_Status VARCHAR(30) CHECK (Screening_Status IN ('Pending','Completed','Deferred')),
    CONSTRAINT fk_screening_unit FOREIGN KEY (Blood_Unit_ID) REFERENCES BLOOD_UNIT(Blood_Unit_ID) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE BLOOD_COMPONENT (
    Component_ID VARCHAR(10) PRIMARY KEY,
    Blood_Unit_ID VARCHAR(10) NOT NULL,
    Component_Type VARCHAR(40) CHECK (Component_Type IN ('Whole Blood','PRBC','FFP','Platelets','Cryoprecipitate')),
    Preparation_Date DATE,
    Expiry_Date DATE,
    Volume_ml DECIMAL(6,2) CHECK (Volume_ml > 0),
    Component_Status VARCHAR(30) CHECK (Component_Status IN ('Available','Reserved','Issued','Expired','Discarded','Quarantined')),
    CONSTRAINT fk_component_unit FOREIGN KEY (Blood_Unit_ID) REFERENCES BLOOD_UNIT(Blood_Unit_ID) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE STORAGE_LOCATION (
    Location_ID VARCHAR(10) PRIMARY KEY,
    Storage_Name VARCHAR(100),
    Storage_Type VARCHAR(100),
    Temperature_Range VARCHAR(100),
    Capacity INT CHECK (Capacity > 0),
    Location_Status VARCHAR(30) CHECK (Location_Status IN ('Active','Inactive','Maintenance'))
);

CREATE TABLE BLOOD_INVENTORY (
    Inventory_ID VARCHAR(10) PRIMARY KEY,
    Component_ID VARCHAR(10) NOT NULL UNIQUE,
    Location_ID VARCHAR(10) NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    Inventory_Status VARCHAR(30) CHECK (Inventory_Status IN ('Available','Reserved','Issued','Quarantined','Expired')),
    Date_Added DATE,
    CONSTRAINT fk_inventory_component FOREIGN KEY (Component_ID) REFERENCES BLOOD_COMPONENT(Component_ID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_location FOREIGN KEY (Location_ID) REFERENCES STORAGE_LOCATION(Location_ID) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE HOSPITAL (
    Hospital_ID VARCHAR(10) PRIMARY KEY,
    Hospital_Name VARCHAR(100) NOT NULL,
    Contact_Person VARCHAR(100),
    Phone VARCHAR(15),
    Email VARCHAR(100),
    Address VARCHAR(200),
    Hospital_Type VARCHAR(30) CHECK (Hospital_Type IN ('Government','Private','Trust','Other'))
);

CREATE TABLE BLOOD_REQUEST (
    Request_ID VARCHAR(10) PRIMARY KEY,
    Hospital_ID VARCHAR(10) NOT NULL,
    Request_Date DATE,
    Required_Date DATE,
    Request_Status VARCHAR(30) CHECK (Request_Status IN ('Pending','Approved','Partially Fulfilled','Fulfilled','Rejected','Cancelled')),
    Priority VARCHAR(20) CHECK (Priority IN ('Low','Normal','High','Emergency')),
    CONSTRAINT fk_request_hospital FOREIGN KEY (Hospital_ID) REFERENCES HOSPITAL(Hospital_ID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_required_date CHECK (Required_Date IS NULL OR Request_Date IS NULL OR Required_Date >= Request_Date)
);

CREATE TABLE REQUEST_DETAIL (
    Request_ID VARCHAR(10),
    Component_ID VARCHAR(10),
    Requested_Quantity INT CHECK (Requested_Quantity > 0),
    Fulfilled_Quantity INT CHECK (Fulfilled_Quantity >= 0 AND Fulfilled_Quantity <= Requested_Quantity),
    PRIMARY KEY (Request_ID, Component_ID),
    CONSTRAINT fk_detail_request FOREIGN KEY (Request_ID) REFERENCES BLOOD_REQUEST(Request_ID) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_detail_component FOREIGN KEY (Component_ID) REFERENCES BLOOD_COMPONENT(Component_ID) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE BLOOD_ISSUE (
    Issue_ID VARCHAR(10) PRIMARY KEY,
    Request_ID VARCHAR(10) NOT NULL,
    Inventory_ID VARCHAR(10) NOT NULL,
    Issue_Date DATE NOT NULL,
    Issued_Quantity INT NOT NULL CHECK (Issued_Quantity > 0),
    Issue_Status VARCHAR(30) CHECK (Issue_Status IN ('Issued','Partially Issued','Pending','Cancelled','Returned')),
    Issued_By VARCHAR(100),
    CONSTRAINT fk_issue_request FOREIGN KEY (Request_ID) REFERENCES BLOOD_REQUEST(Request_ID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_issue_inventory FOREIGN KEY (Inventory_ID) REFERENCES BLOOD_INVENTORY(Inventory_ID) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- =========================================================
-- End of schema
-- =========================================================
