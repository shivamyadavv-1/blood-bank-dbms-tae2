-- BLOOD BANK & BLOOD DONATION MANAGEMENT SYSTEM
-- TAE-2 QUERIES.SQL | PostgreSQL 18

-- 1. INNER JOIN
SELECT d.Donor_ID,d.First_Name,d.Last_Name,bg.ABO_Group,bg.Rh_Factor,
       dn.Donation_Date,dn.Donation_Type,dn.Collection_Status
FROM DONOR d
JOIN DONATION dn ON d.Donor_ID=dn.Donor_ID
JOIN BLOOD_GROUP bg ON dn.Blood_Group_ID=bg.Blood_Group_ID
ORDER BY dn.Donation_Date DESC LIMIT 20;

-- 2. LEFT OUTER JOIN
SELECT d.Donor_ID,d.First_Name,d.Last_Name,dn.Donation_ID,
       dn.Donation_Date,dn.Collection_Status
FROM DONOR d
LEFT JOIN DONATION dn ON d.Donor_ID=dn.Donor_ID
ORDER BY d.Donor_ID LIMIT 20;

-- 3. SELF JOIN
SELECT d1.Donor_ID AS Donor_1,d1.First_Name AS Donor_1_Name,
       d2.Donor_ID AS Donor_2,d2.First_Name AS Donor_2_Name,d1.Last_Name
FROM DONOR d1
JOIN DONOR d2 ON d1.Last_Name=d2.Last_Name AND d1.Donor_ID<d2.Donor_ID
ORDER BY d1.Last_Name LIMIT 20;

-- 4. GROUP BY + HAVING
SELECT bg.ABO_Group,bg.Rh_Factor,COUNT(dn.Donation_ID) AS Total_Donations
FROM BLOOD_GROUP bg
JOIN DONATION dn ON bg.Blood_Group_ID=dn.Blood_Group_ID
GROUP BY bg.ABO_Group,bg.Rh_Factor
HAVING COUNT(dn.Donation_ID)>100
ORDER BY Total_Donations DESC;

-- 5. CORRELATED SUBQUERY
SELECT d.Donor_ID,d.First_Name,d.Last_Name
FROM DONOR d
WHERE (SELECT COUNT(*) FROM DONATION dn WHERE dn.Donor_ID=d.Donor_ID)>2
ORDER BY d.Donor_ID;

-- 6. PARAMETERIZED STORED PROCEDURE
CREATE OR REPLACE PROCEDURE issue_blood(
    p_issue_id VARCHAR(10),p_request_id VARCHAR(10),
    p_inventory_id VARCHAR(10),p_quantity INT,p_issued_by VARCHAR(100))
LANGUAGE plpgsql AS $$
DECLARE v_available INT; v_component_id VARCHAR(10);
BEGIN
    IF p_quantity<=0 THEN RAISE EXCEPTION 'Quantity must be greater than 0'; END IF;
    SELECT Quantity,Component_ID INTO v_available,v_component_id
    FROM BLOOD_INVENTORY WHERE Inventory_ID=p_inventory_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Inventory ID % not found',p_inventory_id; END IF;
    IF p_quantity>=v_available THEN
        RAISE EXCEPTION 'Issue quantity must be less than available quantity (%)',v_available;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM REQUEST_DETAIL
        WHERE Request_ID=p_request_id AND Component_ID=v_component_id
          AND Requested_Quantity>Fulfilled_Quantity) THEN
        RAISE EXCEPTION 'No pending request detail found for this request/component';
    END IF;
    INSERT INTO BLOOD_ISSUE
      (Issue_ID,Request_ID,Inventory_ID,Issue_Date,Issued_Quantity,Issue_Status,Issued_By)
    VALUES (p_issue_id,p_request_id,p_inventory_id,CURRENT_DATE,p_quantity,'Issued',p_issued_by);
    UPDATE BLOOD_INVENTORY
    SET Quantity=Quantity-p_quantity,Inventory_Status='Available'
    WHERE Inventory_ID=p_inventory_id;
    UPDATE REQUEST_DETAIL
    SET Fulfilled_Quantity=Fulfilled_Quantity+p_quantity
    WHERE Request_ID=p_request_id AND Component_ID=v_component_id;
    RAISE NOTICE 'Blood issued successfully. Issue ID: %',p_issue_id;
END; $$;

-- Test used:
-- CALL issue_blood('ISS90001','REQ90008','I000467',1,'Admin');

-- 7. FUNCTIONAL TRIGGER
CREATE OR REPLACE FUNCTION fn_update_request_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM REQUEST_DETAIL
        WHERE Request_ID=NEW.Request_ID
          AND Fulfilled_Quantity<Requested_Quantity) THEN
        UPDATE BLOOD_REQUEST SET Request_Status='Partially Fulfilled'
        WHERE Request_ID=NEW.Request_ID
          AND Request_Status NOT IN ('Cancelled','Rejected');
    ELSE
        UPDATE BLOOD_REQUEST SET Request_Status='Fulfilled'
        WHERE Request_ID=NEW.Request_ID
          AND Request_Status NOT IN ('Cancelled','Rejected');
    END IF;
    RETURN NEW;
END; $$;

CREATE OR REPLACE TRIGGER trg_update_request_status
AFTER UPDATE OF Fulfilled_Quantity ON REQUEST_DETAIL
FOR EACH ROW EXECUTE FUNCTION fn_update_request_status();

-- 8. VIEW 1
CREATE OR REPLACE VIEW vw_available_blood_inventory AS
SELECT bi.Inventory_ID,bc.Component_ID,bc.Component_Type,bg.ABO_Group,bg.Rh_Factor,
       bi.Quantity,bi.Inventory_Status,sl.Storage_Name,sl.Storage_Type
FROM BLOOD_INVENTORY bi
JOIN BLOOD_COMPONENT bc ON bi.Component_ID=bc.Component_ID
JOIN BLOOD_UNIT bu ON bc.Blood_Unit_ID=bu.Blood_Unit_ID
JOIN DONATION dn ON bu.Donation_ID=dn.Donation_ID
JOIN BLOOD_GROUP bg ON dn.Blood_Group_ID=bg.Blood_Group_ID
JOIN STORAGE_LOCATION sl ON bi.Location_ID=sl.Location_ID
WHERE bi.Inventory_Status='Available';

-- 9. VIEW 2
CREATE OR REPLACE VIEW vw_hospital_request_summary AS
SELECT h.Hospital_ID,h.Hospital_Name,br.Request_ID,br.Request_Date,br.Required_Date,
       br.Request_Status,br.Priority,
       SUM(rd.Requested_Quantity) AS Total_Requested,
       SUM(rd.Fulfilled_Quantity) AS Total_Fulfilled
FROM HOSPITAL h
JOIN BLOOD_REQUEST br ON h.Hospital_ID=br.Hospital_ID
JOIN REQUEST_DETAIL rd ON br.Request_ID=rd.Request_ID
GROUP BY h.Hospital_ID,h.Hospital_Name,br.Request_ID,br.Request_Date,
         br.Required_Date,br.Request_Status,br.Priority;

-- View tests
SELECT * FROM vw_available_blood_inventory LIMIT 10;
SELECT * FROM vw_hospital_request_summary LIMIT 10;

-- 10. EXPLAIN ANALYZE BEFORE INDEX #1
EXPLAIN ANALYZE
SELECT dn.Donation_ID,dn.Donation_Date,d.Donor_ID,d.First_Name,d.Last_Name,
       bg.ABO_Group,bg.Rh_Factor
FROM DONATION dn
JOIN DONOR d ON dn.Donor_ID=d.Donor_ID
JOIN BLOOD_GROUP bg ON dn.Blood_Group_ID=bg.Blood_Group_ID
WHERE dn.Blood_Group_ID=1
  AND dn.Donation_Date BETWEEN '2026-01-01' AND '2026-12-31';

-- 11. INDEX #1
CREATE INDEX IF NOT EXISTS idx_donation_bloodgroup_date
ON DONATION(Blood_Group_ID,Donation_Date);

-- 12. EXPLAIN ANALYZE AFTER INDEX #1
EXPLAIN ANALYZE
SELECT dn.Donation_ID,dn.Donation_Date,d.Donor_ID,d.First_Name,d.Last_Name,
       bg.ABO_Group,bg.Rh_Factor
FROM DONATION dn
JOIN DONOR d ON dn.Donor_ID=d.Donor_ID
JOIN BLOOD_GROUP bg ON dn.Blood_Group_ID=bg.Blood_Group_ID
WHERE dn.Blood_Group_ID=1
  AND dn.Donation_Date BETWEEN '2026-01-01' AND '2026-12-31';

-- 13. EXPLAIN ANALYZE BEFORE INDEX #2
EXPLAIN ANALYZE
SELECT bi.Inventory_ID,bi.Component_ID,bc.Component_Type,
       bi.Quantity,bi.Inventory_Status
FROM BLOOD_INVENTORY bi
JOIN BLOOD_COMPONENT bc ON bi.Component_ID=bc.Component_ID
WHERE bi.Inventory_Status='Available'
  AND bc.Component_Type='PRBC'
  AND bi.Quantity>1;

-- 14. INDEX #2
CREATE INDEX IF NOT EXISTS idx_inventory_status_component
ON BLOOD_INVENTORY(Inventory_Status,Component_ID);

-- 15. EXPLAIN ANALYZE AFTER INDEX #2
EXPLAIN ANALYZE
SELECT bi.Inventory_ID,bi.Component_ID,bc.Component_Type,
       bi.Quantity,bi.Inventory_Status
FROM BLOOD_INVENTORY bi
JOIN BLOOD_COMPONENT bc ON bi.Component_ID=bc.Component_ID
WHERE bi.Inventory_Status='Available'
  AND bc.Component_Type='PRBC'
  AND bi.Quantity>1;
