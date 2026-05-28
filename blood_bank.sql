-- ============================================================
--  BLOOD BANK MANAGEMENT SYSTEM
--  NMAM Institute of Technology
--  Dept. of AI & ML Engineering | Course: CS2102-1 DBMS
--  Team: B G Bhardwaj, B Rakesh Bhat, Jnanamshu
-- ============================================================

-- Create & use database
CREATE DATABASE IF NOT EXISTS blood_bank_db;
USE blood_bank_db;

-- ============================================================
-- TABLE 1: donors
-- Stores personal details of every registered blood donor
-- ============================================================
CREATE TABLE donors (
    donor_id       INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100)  NOT NULL,
    age            INT           NOT NULL,
    gender         ENUM('Male','Female','Other') NOT NULL,
    blood_group    ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    phone          VARCHAR(15)   NOT NULL UNIQUE,
    email          VARCHAR(100)  UNIQUE,
    address        TEXT,
    last_donation_date DATE,

    -- Constraints
    CONSTRAINT chk_age CHECK (age >= 18 AND age <= 65)
);

-- ============================================================
-- TABLE 2: blood_inventory
-- Tracks total available units per blood group
-- ============================================================
CREATE TABLE blood_inventory (
    inventory_id     INT AUTO_INCREMENT PRIMARY KEY,
    blood_group      ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL UNIQUE,
    units_available  INT NOT NULL DEFAULT 0,
    last_updated     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_units CHECK (units_available >= 0)
);

-- Pre-populate inventory with all 8 blood groups (0 units to start)
INSERT INTO blood_inventory (blood_group, units_available) VALUES
    ('A+',  0), ('A-',  0),
    ('B+',  0), ('B-',  0),
    ('AB+', 0), ('AB-', 0),
    ('O+',  0), ('O-',  0);

-- ============================================================
-- TABLE 3: blood_units
-- Each row = one individual blood bag collected from a donor
-- ============================================================
CREATE TABLE blood_units (
    unit_id         INT AUTO_INCREMENT PRIMARY KEY,
    blood_group     ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    donor_id        INT NOT NULL,
    collection_date DATE NOT NULL,
    expiry_date     DATE NOT NULL,
    status          ENUM('Available','Used','Expired') NOT NULL DEFAULT 'Available',

    -- Foreign Key
    CONSTRAINT fk_unit_donor FOREIGN KEY (donor_id)
        REFERENCES donors(donor_id) ON DELETE RESTRICT,

    -- Constraints
    CONSTRAINT chk_expiry CHECK (expiry_date > collection_date)
);

-- ============================================================
-- TABLE 4: blood_requests
-- Records every blood request made by hospitals/patients
-- ============================================================
CREATE TABLE blood_requests (
    request_id      INT AUTO_INCREMENT PRIMARY KEY,
    patient_name    VARCHAR(100) NOT NULL,
    blood_group     ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_needed    INT          NOT NULL,
    hospital_name   VARCHAR(150) NOT NULL,
    request_date    DATE         NOT NULL DEFAULT (CURRENT_DATE),
    status          ENUM('Pending','Fulfilled','Rejected') NOT NULL DEFAULT 'Pending',

    -- Constraints
    CONSTRAINT chk_units_needed CHECK (units_needed > 0)
);

-- ============================================================
-- TABLE 5: donations
-- Records every donation event; links donor to blood unit
-- ============================================================
CREATE TABLE donations (
    donation_id    INT AUTO_INCREMENT PRIMARY KEY,
    donor_id       INT  NOT NULL,
    unit_id        INT  NOT NULL,
    donation_date  DATE NOT NULL,
    quantity       INT  NOT NULL DEFAULT 1,

    -- Foreign Keys
    CONSTRAINT fk_don_donor FOREIGN KEY (donor_id)
        REFERENCES donors(donor_id) ON DELETE RESTRICT,
    CONSTRAINT fk_don_unit  FOREIGN KEY (unit_id)
        REFERENCES blood_units(unit_id) ON DELETE RESTRICT,

    -- Constraints
    CONSTRAINT chk_quantity CHECK (quantity > 0)
);


-- ============================================================
-- TRIGGERS
-- ============================================================

DELIMITER $$

-- TRIGGER 1: After a new blood unit is added (donation recorded),
--            automatically increase inventory count
CREATE TRIGGER trg_increase_inventory
AFTER INSERT ON blood_units
FOR EACH ROW
BEGIN
    UPDATE blood_inventory
    SET units_available = units_available + 1
    WHERE blood_group = NEW.blood_group;
END$$

-- TRIGGER 2: After a blood unit status changes to 'Used' or 'Expired',
--            automatically decrease inventory count
CREATE TRIGGER trg_decrease_inventory
AFTER UPDATE ON blood_units
FOR EACH ROW
BEGIN
    IF NEW.status IN ('Used', 'Expired') AND OLD.status = 'Available' THEN
        UPDATE blood_inventory
        SET units_available = units_available - 1
        WHERE blood_group = NEW.blood_group;
    END IF;
END$$

-- TRIGGER 3: After a blood request is fulfilled,
--            update the status of one matching blood unit to 'Used'
CREATE TRIGGER trg_fulfill_request
AFTER UPDATE ON blood_requests
FOR EACH ROW
BEGIN
    IF NEW.status = 'Fulfilled' AND OLD.status = 'Pending' THEN
        UPDATE blood_units
        SET status = 'Used'
        WHERE blood_group = NEW.blood_group
          AND status = 'Available'
        LIMIT NEW.units_needed;
    END IF;
END$$

-- TRIGGER 4: Prevent donation if donor donated within last 90 days
CREATE TRIGGER trg_check_donation_gap
BEFORE INSERT ON donations
FOR EACH ROW
BEGIN
    DECLARE last_date DATE;
    SELECT last_donation_date INTO last_date
    FROM donors WHERE donor_id = NEW.donor_id;

    IF last_date IS NOT NULL AND DATEDIFF(NEW.donation_date, last_date) < 90 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Donor must wait 90 days between donations.';
    END IF;
END$$

DELIMITER ;


-- ============================================================
-- SAMPLE DATA  (full realistic dataset)
-- ============================================================

-- ------------------------------------------------------------
-- 20 DONORS  (all blood groups covered, mixed gender/age/city)
-- NOTE: last_donation_date set to NULL here;
--       updated below after donations are inserted.
-- ------------------------------------------------------------
INSERT INTO donors (name, age, gender, blood_group, phone, email, address, last_donation_date) VALUES
-- team members first
('Rakesh Bhat',       21, 'Male',   'B+',  '9876543210', 'rakesh@email.com',    'Mangaluru, Karnataka',  NULL),
('Bhardwaj B G',      22, 'Male',   'O+',  '9876543211', 'bhardwaj@email.com',  'Udupi, Karnataka',      NULL),
('Jnanamshu K',       20, 'Male',   'A+',  '9876543212', 'jnana@email.com',     'Karkala, Karnataka',    NULL),
-- remaining 17 donors
('Priya Shetty',      25, 'Female', 'AB+', '9876543213', 'priya@email.com',     'Mangaluru, Karnataka',  NULL),
('Suresh Kumar',      30, 'Male',   'A-',  '9876543214', 'suresh@email.com',    'Puttur, Karnataka',     NULL),
('Anitha Rao',        28, 'Female', 'O-',  '9876543215', 'anitha@email.com',    'Udupi, Karnataka',      NULL),
('Kiran Hegde',       35, 'Male',   'B-',  '9876543216', 'kiran@email.com',     'Manipal, Karnataka',    NULL),
('Deepa Nayak',       23, 'Female', 'A+',  '9876543217', 'deepa@email.com',     'Mangaluru, Karnataka',  NULL),
('Vinod Prabhu',      40, 'Male',   'O+',  '9876543218', 'vinod@email.com',     'Bantwal, Karnataka',    NULL),
('Savitha Kamath',    32, 'Female', 'AB-', '9876543219', 'savitha@email.com',   'Mangaluru, Karnataka',  NULL),
('Mohan Das',         45, 'Male',   'B+',  '9876543220', 'mohan@email.com',     'Sullia, Karnataka',     NULL),
('Rekha Suvarna',     27, 'Female', 'A-',  '9876543221', 'rekha@email.com',     'Udupi, Karnataka',      NULL),
('Harish Bhandary',   33, 'Male',   'O+',  '9876543222', 'harish@email.com',    'Mangaluru, Karnataka',  NULL),
('Lavanya Poojari',   22, 'Female', 'A+',  '9876543223', 'lavanya@email.com',   'Karkala, Karnataka',    NULL),
('Ganesh Kotian',     38, 'Male',   'AB+', '9876543224', 'ganesh@email.com',    'Mangaluru, Karnataka',  NULL),
('Nisha Bangera',     29, 'Female', 'B+',  '9876543225', 'nisha@email.com',     'Puttur, Karnataka',     NULL),
('Ravi Shetty',       50, 'Male',   'O-',  '9876543226', 'ravi@email.com',      'Mangaluru, Karnataka',  NULL),
('Suma Alva',         36, 'Female', 'B-',  '9876543227', 'suma@email.com',      'Udupi, Karnataka',      NULL),
('Prasad Mundkur',    42, 'Male',   'A+',  '9876543228', 'prasad@email.com',    'Mangaluru, Karnataka',  NULL),
('Kavitha Salian',    31, 'Female', 'O+',  '9876543229', 'kavitha@email.com',   'Bantwal, Karnataka',    NULL);

-- ------------------------------------------------------------
-- 22 BLOOD UNITS
-- Spread across Nov 2025 – Mar 2026
-- Mix of Available / Used / Expired statuses
-- Triggers will auto-update inventory for 'Available' inserts
-- ------------------------------------------------------------

-- Temporarily disable the donation-gap trigger for clean seeding
-- (we set last_donation_date manually below)
SET @OLD_SQL_MODE = @@SQL_MODE;
SET SQL_MODE = '';

INSERT INTO blood_units (blood_group, donor_id, collection_date, expiry_date, status) VALUES
-- November 2025  (older — some expired/used)
('A+',  3,  '2025-11-05', '2026-02-05', 'Expired'),   -- unit 1
('O+',  2,  '2025-11-10', '2026-02-10', 'Used'),       -- unit 2
('B+',  1,  '2025-11-20', '2026-02-20', 'Used'),       -- unit 3
('A-',  5,  '2025-11-25', '2026-02-25', 'Expired'),    -- unit 4

-- December 2025  (some used, some available)
('AB+', 4,  '2025-12-03', '2026-03-03', 'Used'),       -- unit 5
('O-',  6,  '2025-12-08', '2026-03-08', 'Available'),  -- unit 6
('B-',  7,  '2025-12-15', '2026-03-15', 'Available'),  -- unit 7
('A+',  8,  '2025-12-20', '2026-03-20', 'Used'),       -- unit 8
('O+',  9,  '2025-12-28', '2026-03-28', 'Available'),  -- unit 9

-- January 2026
('B+',  10, '2026-01-05', '2026-04-05', 'Available'),  -- unit 10
('A-',  11, '2026-01-10', '2026-04-10', 'Available'),  -- unit 11
('AB-', 12, '2026-01-15', '2026-04-15', 'Available'),  -- unit 12  (rare AB-)
('O+',  13, '2026-01-18', '2026-04-18', 'Used'),       -- unit 13
('A+',  14, '2026-01-22', '2026-04-22', 'Available'),  -- unit 14
('B+',  15, '2026-01-28', '2026-04-28', 'Available'),  -- unit 15

-- February 2026
('O-',  16, '2026-02-02', '2026-05-02', 'Available'),  -- unit 16  (universal donor)
('AB+', 17, '2026-02-07', '2026-05-07', 'Available'),  -- unit 17
('A+',  18, '2026-02-14', '2026-05-14', 'Available'),  -- unit 18
('O+',  19, '2026-02-19', '2026-05-19', 'Available'),  -- unit 19

-- March 2026  (very fresh)
('B-',  20, '2026-03-01', '2026-06-01', 'Available'),  -- unit 20
('A-',  3,  '2026-03-05', '2026-06-05', 'Available'),  -- unit 21  (donor 3 donates again, >90 days gap)
('O+',  2,  '2026-03-10', '2026-06-10', 'Available');  -- unit 22

SET SQL_MODE = @OLD_SQL_MODE;

-- Manually fix inventory for Used/Expired units
-- (trigger only fires on INSERT as 'Available'; used/expired don't add to stock)
-- The INSERT trigger already added +1 for every insert above.
-- Now subtract for the ones that are Used or Expired (units 1,2,3,4,5,8,13)
UPDATE blood_inventory SET units_available = units_available - 1 WHERE blood_group = 'A+';  -- unit 1 expired
UPDATE blood_inventory SET units_available = units_available - 1 WHERE blood_group = 'O+';  -- unit 2 used
UPDATE blood_inventory SET units_available = units_available - 1 WHERE blood_group = 'B+';  -- unit 3 used
UPDATE blood_inventory SET units_available = units_available - 1 WHERE blood_group = 'A-';  -- unit 4 expired
UPDATE blood_inventory SET units_available = units_available - 1 WHERE blood_group = 'AB+'; -- unit 5 used
UPDATE blood_inventory SET units_available = units_available - 1 WHERE blood_group = 'A+';  -- unit 8 used
UPDATE blood_inventory SET units_available = units_available - 1 WHERE blood_group = 'O+';  -- unit 13 used

-- ------------------------------------------------------------
-- 20 DONATIONS  (links donors to units, spread across months)
-- ------------------------------------------------------------
INSERT INTO donations (donor_id, unit_id, donation_date, quantity) VALUES
(3,  1,  '2025-11-05', 1),
(2,  2,  '2025-11-10', 1),
(1,  3,  '2025-11-20', 1),
(5,  4,  '2025-11-25', 1),
(4,  5,  '2025-12-03', 1),
(6,  6,  '2025-12-08', 1),
(7,  7,  '2025-12-15', 1),
(8,  8,  '2025-12-20', 1),
(9,  9,  '2025-12-28', 1),
(10, 10, '2026-01-05', 1),
(11, 11, '2026-01-10', 1),
(12, 12, '2026-01-15', 1),
(13, 13, '2026-01-18', 1),
(14, 14, '2026-01-22', 1),
(15, 15, '2026-01-28', 1),
(16, 16, '2026-02-02', 1),
(17, 17, '2026-02-07', 1),
(18, 18, '2026-02-14', 1),
(19, 19, '2026-02-19', 1),
(20, 20, '2026-03-01', 1);

-- ------------------------------------------------------------
-- Update last_donation_date for all 20 donors
-- ------------------------------------------------------------
UPDATE donors SET last_donation_date = '2025-11-20' WHERE donor_id = 1;
UPDATE donors SET last_donation_date = '2025-11-10' WHERE donor_id = 2;
UPDATE donors SET last_donation_date = '2025-11-05' WHERE donor_id = 3;
UPDATE donors SET last_donation_date = '2025-12-03' WHERE donor_id = 4;
UPDATE donors SET last_donation_date = '2025-11-25' WHERE donor_id = 5;
UPDATE donors SET last_donation_date = '2025-12-08' WHERE donor_id = 6;
UPDATE donors SET last_donation_date = '2025-12-15' WHERE donor_id = 7;
UPDATE donors SET last_donation_date = '2025-12-20' WHERE donor_id = 8;
UPDATE donors SET last_donation_date = '2025-12-28' WHERE donor_id = 9;
UPDATE donors SET last_donation_date = '2026-01-05' WHERE donor_id = 10;
UPDATE donors SET last_donation_date = '2026-01-10' WHERE donor_id = 11;
UPDATE donors SET last_donation_date = '2026-01-15' WHERE donor_id = 12;
UPDATE donors SET last_donation_date = '2026-01-18' WHERE donor_id = 13;
UPDATE donors SET last_donation_date = '2026-01-22' WHERE donor_id = 14;
UPDATE donors SET last_donation_date = '2026-01-28' WHERE donor_id = 15;
UPDATE donors SET last_donation_date = '2026-02-02' WHERE donor_id = 16;
UPDATE donors SET last_donation_date = '2026-02-07' WHERE donor_id = 17;
UPDATE donors SET last_donation_date = '2026-02-14' WHERE donor_id = 18;
UPDATE donors SET last_donation_date = '2026-02-19' WHERE donor_id = 19;
UPDATE donors SET last_donation_date = '2026-03-01' WHERE donor_id = 20;

-- ------------------------------------------------------------
-- 15 BLOOD REQUESTS
-- Mix of Pending / Fulfilled / Rejected, spread Nov 2025–Mar 2026
-- ------------------------------------------------------------
INSERT INTO blood_requests (patient_name, blood_group, units_needed, hospital_name, request_date, status) VALUES
('Anil Sharma',      'B+',  1, 'KMC Hospital Mangaluru',              '2025-11-22', 'Fulfilled'),
('Meena Rao',        'O+',  2, 'Wenlock District Hospital Mangaluru', '2025-11-28', 'Fulfilled'),
('Arjun Nayak',      'A+',  1, 'Father Muller Medical College',       '2025-12-05', 'Fulfilled'),
('Sunita Pinto',     'AB+', 1, 'A J Hospital Mangaluru',              '2025-12-10', 'Fulfilled'),
('Ramesh Devadiga',  'A-',  1, 'Kasturba Medical College Manipal',    '2025-12-18', 'Rejected'),
('Girija Acharya',   'O-',  1, 'Manipal Hospital Udupi',              '2026-01-06', 'Fulfilled'),
('Nagaraj Shetty',   'B-',  1, 'Yenepoya Medical College Mangaluru',  '2026-01-16', 'Fulfilled'),
('Pushpa Amin',      'A+',  2, 'Unity Hospital Mangaluru',            '2026-01-25', 'Fulfilled'),
('Dinesh Alva',      'O+',  1, 'Government Hospital Puttur',          '2026-02-03', 'Fulfilled'),
('Shobha Kamath',    'AB-', 1, 'District Hospital Udupi',             '2026-02-10', 'Fulfilled'),
('Venkatesh Bhat',   'B+',  1, 'Justice K S Hegde Hospital Deralakatte', '2026-02-20', 'Fulfilled'),
('Padma Ullal',      'O+',  1, 'Srinivas Institute Hospital Surathkal',  '2026-03-01', 'Pending'),
('Sunil Rodrigues',  'A+',  2, 'Government Hospital Karkala',         '2026-03-08', 'Pending'),
('Leela Crasta',     'B-',  1, 'Government Hospital Bantwal',         '2026-03-12', 'Pending'),
('Mahesh Kunder',    'O-',  1, 'SDM Hospital Dharwad',                '2026-03-15', 'Pending');


-- ============================================================
-- USEFUL QUERIES (Reports)
-- ============================================================

-- Report 1: Current blood availability (all groups)
SELECT blood_group, units_available
FROM blood_inventory
ORDER BY blood_group;

-- Report 2: All donors and their details
SELECT donor_id, name, age, blood_group, phone, last_donation_date
FROM donors
ORDER BY name;

-- Report 3: Blood units expiring within next 30 days
SELECT unit_id, blood_group, expiry_date,
       DATEDIFF(expiry_date, CURDATE()) AS days_until_expiry
FROM blood_units
WHERE status = 'Available'
  AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
ORDER BY expiry_date;

-- Report 4: Monthly donation statistics
SELECT MONTHNAME(donation_date) AS month,
       COUNT(*) AS total_donations
FROM donations
GROUP BY MONTH(donation_date), MONTHNAME(donation_date)
ORDER BY MONTH(donation_date);

-- Report 5: Pending blood requests
SELECT request_id, patient_name, blood_group,
       units_needed, hospital_name, request_date
FROM blood_requests
WHERE status = 'Pending'
ORDER BY request_date;

-- Report 6: Full donor + donation history (JOIN)
SELECT d.name, d.blood_group, dn.donation_date,
       bu.unit_id, bu.expiry_date, bu.status
FROM donors d
JOIN donations dn ON d.donor_id = dn.donor_id
JOIN blood_units bu ON dn.unit_id = bu.unit_id
ORDER BY dn.donation_date DESC;

-- Report 7: Blood availability summary with request count
SELECT bi.blood_group,
       bi.units_available,
       COUNT(br.request_id) AS pending_requests
FROM blood_inventory bi
LEFT JOIN blood_requests br
       ON bi.blood_group = br.blood_group AND br.status = 'Pending'
GROUP BY bi.blood_group, bi.units_available
ORDER BY bi.blood_group;

-- ============================================================
-- EXTRA BATCH  (donors 21–30, units 23–32, donations, requests)
-- ============================================================

-- ------------------------------------------------------------
-- 10 MORE DONORS  (donor_id 21–30)
-- ------------------------------------------------------------
INSERT INTO donors (name, age, gender, blood_group, phone, email, address, last_donation_date) VALUES
('Abhishek Nair',     24, 'Male',   'O+',  '9845001001', 'abhi@email.com',     'Mangaluru, Karnataka',  NULL),
('Chandrika Prabhu',  29, 'Female', 'A+',  '9845001002', 'chandu@email.com',   'Udupi, Karnataka',      NULL),
('Dhanraj Shetty',    37, 'Male',   'B+',  '9845001003', 'dhanraj@email.com',  'Karkala, Karnataka',    NULL),
('Esha Fernandes',    26, 'Female', 'O-',  '9845001004', 'esha@email.com',     'Mangaluru, Karnataka',  NULL),
('Farhan Shaikh',     31, 'Male',   'AB+', '9845001005', 'farhan@email.com',   'Mangaluru, Karnataka',  NULL),
('Geetha Bangera',    44, 'Female', 'A-',  '9845001006', 'geetha@email.com',   'Puttur, Karnataka',     NULL),
('Harshith Amin',     19, 'Male',   'B-',  '9845001007', 'harshith@email.com', 'Bantwal, Karnataka',    NULL),
('Indira Uchil',      55, 'Female', 'O+',  '9845001008', 'indira@email.com',   'Manipal, Karnataka',    NULL),
('Jagadeesh Ballal',  48, 'Male',   'A+',  '9845001009', 'jagadeesh@email.com','Mangaluru, Karnataka',  NULL),
('Kavya Moolya',      22, 'Female', 'AB-', '9845001010', 'kavya@email.com',    'Udupi, Karnataka',      NULL);

-- ------------------------------------------------------------
-- 10 MORE BLOOD UNITS  (unit_id 23–32)
-- Dates spread across Mar–Apr 2026 (fresh stock)
-- ------------------------------------------------------------
INSERT INTO blood_units (blood_group, donor_id, collection_date, expiry_date, status) VALUES
('O+',  21, '2026-03-02', '2026-06-02', 'Available'),   -- unit 23
('A+',  22, '2026-03-04', '2026-06-04', 'Available'),   -- unit 24
('B+',  23, '2026-03-06', '2026-06-06', 'Available'),   -- unit 25
('O-',  24, '2026-03-08', '2026-06-08', 'Available'),   -- unit 26  (universal donor — rare)
('AB+', 25, '2026-03-10', '2026-06-10', 'Available'),   -- unit 27
('A-',  26, '2026-03-12', '2026-06-12', 'Available'),   -- unit 28
('B-',  27, '2026-03-13', '2026-06-13', 'Available'),   -- unit 29
('O+',  28, '2026-03-14', '2026-06-14', 'Available'),   -- unit 30
('A+',  29, '2026-03-16', '2026-06-16', 'Available'),   -- unit 31
('AB-', 30, '2026-03-18', '2026-06-18', 'Available');   -- unit 32  (rarest blood group)

-- ------------------------------------------------------------
-- 10 MORE DONATIONS
-- ------------------------------------------------------------
INSERT INTO donations (donor_id, unit_id, donation_date, quantity) VALUES
(21, 23, '2026-03-02', 1),
(22, 24, '2026-03-04', 1),
(23, 25, '2026-03-06', 1),
(24, 26, '2026-03-08', 1),
(25, 27, '2026-03-10', 1),
(26, 28, '2026-03-12', 1),
(27, 29, '2026-03-13', 1),
(28, 30, '2026-03-14', 1),
(29, 31, '2026-03-16', 1),
(30, 32, '2026-03-18', 1);

-- Update last_donation_date for new donors
UPDATE donors SET last_donation_date = '2026-03-02' WHERE donor_id = 21;
UPDATE donors SET last_donation_date = '2026-03-04' WHERE donor_id = 22;
UPDATE donors SET last_donation_date = '2026-03-06' WHERE donor_id = 23;
UPDATE donors SET last_donation_date = '2026-03-08' WHERE donor_id = 24;
UPDATE donors SET last_donation_date = '2026-03-10' WHERE donor_id = 25;
UPDATE donors SET last_donation_date = '2026-03-12' WHERE donor_id = 26;
UPDATE donors SET last_donation_date = '2026-03-13' WHERE donor_id = 27;
UPDATE donors SET last_donation_date = '2026-03-14' WHERE donor_id = 28;
UPDATE donors SET last_donation_date = '2026-03-16' WHERE donor_id = 29;
UPDATE donors SET last_donation_date = '2026-03-18' WHERE donor_id = 30;

-- ------------------------------------------------------------
-- 10 MORE BLOOD REQUESTS  (request_id 16–25)
-- Mix of hospitals and statuses, Mar–Apr 2026
-- ------------------------------------------------------------
INSERT INTO blood_requests (patient_name, blood_group, units_needed, hospital_name, request_date, status) VALUES
('Rohan Saldanha',   'O+',  1, 'KIMS Hospital Hubli',                  '2026-03-03', 'Fulfilled'),
('Triveni Poojari',  'A+',  1, 'Bangalore Baptist Hospital',           '2026-03-05', 'Fulfilled'),
('Akbar Khan',       'B+',  2, 'Victoria Hospital Bangalore',          '2026-03-07', 'Pending'),
('Saritha Devadiga', 'O-',  1, 'Narayana Health City Bangalore',       '2026-03-09', 'Fulfilled'),
('Nitesh Anchan',    'AB+', 1, 'NIMHANS Hospital Bangalore',           '2026-03-11', 'Pending'),
('Bhavana Shetty',   'A-',  1, 'St. Philomena Hospital Mysuru',        '2026-03-13', 'Pending'),
('Prasanna Nayak',   'B-',  1, 'JSS Hospital Mysuru',                  '2026-03-15', 'Pending'),
('Usha Prabhu',      'O+',  2, 'Government Hospital Hassan',           '2026-03-17', 'Pending'),
('Vinayak Hegde',    'A+',  1, 'District Hospital Shimoga',            '2026-03-19', 'Pending'),
('Yashodhara Alva',  'AB-', 1, 'ESIC Hospital Belagavi',               '2026-03-20', 'Pending');

-- ============================================================
-- END OF SCRIPT
-- ============================================================
