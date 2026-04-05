--DDL Task

-- Creating database 
CREATE DATABASE mountaineering_club;
-- Creating schema
CREATE SCHEMA IF NOT EXISTS mountaineering_data;; 


-- Create all the tables from MountaineeringClub_diagram.png and alter all tables to have all the foreign keys. Parent tables first
CREATE TABLE IF NOT EXISTS mountaineering_data.members (
    member_id SERIAL PRIMARY KEY,
    full_name VARCHAR(60) NOT NULL ,
    date_of_birth DATE NOT NULL CHECK (date_of_birth > '2000-01-01'),
    phone_number varchar(12) NOT NULL UNIQUE,  
    email varchar(30) NOT NULL UNIQUE,
    emergency_contact_id INT 
);

CREATE TABLE IF NOT EXISTS mountaineering_data.climbs (
    climb_id SERIAL PRIMARY KEY,
    mountain_id INT,
    scheduled_start DATE NOT NULL CHECK (scheduled_start > '2000-01-01'),
    scheduled_end DATE NOT NULL CHECK (scheduled_end > '2000-01-01')
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.mountains (
    mountain_id SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL,
    evaluation_meters INT NOT NULL CHECK (evaluation_meters > 0),
    difficulty_rating INT NOT NULL,
    location_region_id INT NOT NULL
);

ALTER TABLE  mountaineering_data.climbs
ADD CONSTRAINT fk_mountain
FOREIGN KEY (mountain_id)
REFERENCES mountaineering_data.mountains (mountain_id);

CREATE TABLE IF NOT EXISTS mountaineering_data.emergency_contacts (
    emergency_contact_id SERIAL PRIMARY KEY,
    emergency_contact_full_name VARCHAR(60) NOT NULL,
    emergency_contact_phone_number varchar(12) NOT NULL UNIQUE 
);

CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_inventory (
    equipment_id SERIAL PRIMARY KEY,
    model_name_id INT NOT NULL,
    serial_number varchar(30) NOT NULL UNIQUE,
    equipment_type_id INT NOT NULL,
    last_inspection_date DATE NOT NULL CHECK (last_inspection_date > '2000-01-01')
    );   


CREATE TABLE IF NOT EXISTS mountaineering_data.location_region_description (
    location_region_id SERIAL PRIMARY KEY,
    region_description VARCHAR(60) NOT NULL
);

ALTER TABLE mountaineering_data.mountains
ADD CONSTRAINT fk_region
FOREIGN KEY (location_region_id)
REFERENCES mountaineering_data.location_region_description (location_region_id);

CREATE TABLE IF NOT EXISTS mountaineering_data.climb_status_log (
    log_id SERIAL PRIMARY KEY,
    climb_id INT REFERENCES mountaineering_data.climbs (climb_id),
    status_id int NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now() CHECK (changed_at > '2000-01-01 00:00:00+00')
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.climb_status_types (
    status_id SERIAL PRIMARY KEY,
    status_label varchar(20) NOT NULL 
    );



CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_assignments (
    assignment_id SERIAL PRIMARY KEY,
	equipment_id INT REFERENCES mountaineering_data.equipment_inventory (equipment_id),
    climb_id INT REFERENCES mountaineering_data.climbs (climb_id),
    member_id INT REFERENCES mountaineering_data.members (member_id),
    checkout_date DATE NOT NULL CHECK (checkout_date > '2000-01-01'),
    return_date DATE CHECK (return_date > '2000-01-01') -- Can be NULL if equipment is in use
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_type (
    equipment_type_id SERIAL PRIMARY KEY,
	equipment_type_description VARCHAR(50)
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.member_gear_competency (
    member_id  INT REFERENCES mountaineering_data.members (member_id),
    equipment_type_id INT REFERENCES mountaineering_data.equipment_type (equipment_type_id),
	is_certified BOOLEAN NOT NULL  DEFAULT FALSE,
	PRIMARY KEY (member_id, equipment_type_id)
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.participation_roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR (50) NOT NULL
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.climb_participants (
    participation_id SERIAL PRIMARY KEY,
    climb_id INT REFERENCES mountaineering_data.climbs (climb_id),
    member_id INT REFERENCES mountaineering_data.members (member_id),
    role_id INT REFERENCES mountaineering_data.participation_roles (role_id),
    joined_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, -- default is current time for when user in app adds member in the middle of a climb
    left_at timestamptz  -- Can be NULL if nobody left the climb
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.safety_mentorships (
    mentorship_id SERIAL PRIMARY KEY,
    mentor_id INT REFERENCES mountaineering_data.members (member_id),
    mentee_id INT REFERENCES mountaineering_data.members (member_id) CONSTRAINT no_self_mentoring CHECK (mentee_id <> mentor_id), --Constraint needed to prevent a member from mentoring themselves 
    start_date DATE  NOT NULL CHECK ( start_date > '2000-01-01'),
    end_date DATE  NOT NULL CHECK (end_date > '2000-01-01')
    );
CREATE TABLE IF NOT EXISTS mountaineering_data.member_experience_history (
    history_id SERIAL PRIMARY KEY,
    member_id INT REFERENCES mountaineering_data.members (member_id),
    level_id INT ,
    achieved_date DATE,
    certification_ref VARCHAR(50)
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.experience_levels (
    level_id SERIAL PRIMARY KEY,
    level_name varchar(15) NOT NULL
    );

ALTER TABLE mountaineering_data.member_experience_history 
ADD CONSTRAINT fk_level
FOREIGN KEY (level_id)
REFERENCES mountaineering_data.experience_levels (level_id);

CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_description (
    model_name_id SERIAL PRIMARY KEY,
    model_name varchar(50) NOT NULL
    );

ALTER TABLE mountaineering_data.equipment_inventory 
ADD CONSTRAINT fk_model_name
FOREIGN KEY (model_name_id)
REFERENCES mountaineering_data.equipment_description (model_name_id);

ALTER TABLE mountaineering_data.members 
ADD CONSTRAINT fk_emergency_contacts
FOREIGN KEY (emergency_contact_id)
REFERENCES mountaineering_data.emergency_contacts (emergency_contact_id);

ALTER TABLE mountaineering_data.climb_status_log 
ADD CONSTRAINT fk_climb_status_types
FOREIGN KEY (status_id)
REFERENCES mountaineering_data.climb_status_types (status_id);

-- Populate tables
-- 1. Regions & Status Types
INSERT INTO mountaineering_data.location_region_description (region_description) VALUES ('Caucasus Mountains'), ('Swiss Alps');
INSERT INTO mountaineering_data.climb_status_types (status_label) VALUES ('Scheduled'), ('In Progress');

-- 2. Roles, Experience Levels, & Equipment Meta
INSERT INTO mountaineering_data.participation_roles (role_name) VALUES ('Lead Climber'), ('Safety Officer');
INSERT INTO mountaineering_data.experience_levels (level_name) VALUES ('Beginner'), ('Expert');
INSERT INTO mountaineering_data.equipment_type (equipment_type_description) VALUES ('Harness'), ('Crampons');
INSERT INTO mountaineering_data.equipment_description (model_name) VALUES ('Petzl Corax'), ('Black Diamond Sabretooth');

-- 3. Emergency Contacts (Needed for Members)
INSERT INTO mountaineering_data.emergency_contacts (emergency_contact_full_name, emergency_contact_phone_number) 
VALUES ('Sarah Connor', '+15551112222'), ('John Doe', '+15553334444');
-- 4. Mountains (References Regions)
INSERT INTO mountaineering_data.mountains (name, evaluation_meters, difficulty_rating, location_region_id) 
VALUES ('Mount Elbrus', 5642, 3, 1), ('Matterhorn', 4478, 5, 2);

-- 5. Members (References Emergency Contacts)
INSERT INTO mountaineering_data.members (full_name, date_of_birth, phone_number, email, emergency_contact_id) 
VALUES ('Alex Honnold', '2005-06-15', '+15550123456', 'alex@test.com', 1), 
       ('Reinhold Messner', '2002-11-20', '+15559876543', 'reinhold@test.com', 2);
-- 6. Climbs (References Mountains)
INSERT INTO mountaineering_data.climbs (mountain_id, scheduled_start, scheduled_end) 
VALUES (1, '2026-06-01', '2026-06-10'), (2, '2026-08-15', '2026-08-20');

-- 7. Equipment Inventory (References Model and Type)
INSERT INTO mountaineering_data.equipment_inventory (model_name_id, serial_number, equipment_type_id, last_inspection_date) 
VALUES (1, 'SN-PTZL-001', 1, '2026-01-10'), (2, 'SN-BD-999', 2, '2026-02-15');
-- 8. Climb Status Logs & Participants
INSERT INTO mountaineering_data.climb_status_log (climb_id, status_id) VALUES (1, 1), (2, 2);
INSERT INTO mountaineering_data.climb_participants (climb_id, member_id, role_id) VALUES (1, 1, 1), (1, 2, 2);

-- 9. Gear Assignments & Competency
INSERT INTO mountaineering_data.equipment_assignments (equipment_id, climb_id, member_id, checkout_date) 
VALUES (1, 1, 1, '2026-05-30'), (2, 1, 2, '2026-05-30');
INSERT INTO mountaineering_data.member_gear_competency (member_id, equipment_type_id, is_certified) 
VALUES (1, 1, TRUE), (2, 2, TRUE);

-- 10. Experience History & Mentorships
INSERT INTO mountaineering_data.member_experience_history (member_id, level_id, achieved_date, certification_ref) 
VALUES (1, 2, '2025-05-01', 'CERT-99'), (2, 2, '2024-01-10', 'CERT-01');
INSERT INTO mountaineering_data.safety_mentorships (mentor_id, mentee_id, start_date, end_date) 
VALUES (2, 1, '2026-01-01', '2026-12-31');


-- Add 'record_ts' field 

ALTER TABLE mountaineering_data.members ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.emergency_contacts ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.mountains ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.location_region_description ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.climbs ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.climb_status_log ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.climb_status_types ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.climb_participants ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.participation_roles ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.equipment_inventory ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.equipment_assignments ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.equipment_type ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.equipment_description ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.member_gear_competency ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.safety_mentorships ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.member_experience_history ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.experience_levels ADD COLUMN record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

/*COMMENTS:
 * Purposes of constraints - I add CHECK (date > '2000-01-01') so that data records cant be before that date.
 * Unique constraints are adde as needed. Phone is in varchar so '+' is not lost. Constraint added to make it impossible for mentor to be their own mentee
 * NOT NULL prevents nulls.
 * */
