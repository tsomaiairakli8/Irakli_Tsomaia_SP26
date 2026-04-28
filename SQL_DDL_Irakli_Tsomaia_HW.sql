--DDL Task

-- Creating database 
CREATE DATABASE mountaineering_club;
-- Creating schema
CREATE SCHEMA IF NOT EXISTS mountaineering_data;

/*GENEREAL COMMENTS:
 * Purposes of constraints - I add CHECK (date > '2000-01-01') so that data records cant be before that date.
 * Unique constraints are adde as needed. Phone is in varchar so '+' is not lost,  using an INT would lose it. Constraint added to make it impossible for mentor to be their own mentee
 * NOT NULL prevents nulls.
 * 
 * */


CREATE TABLE IF NOT EXISTS mountaineering_data.location_region_description (
    location_region_id SERIAL PRIMARY KEY,
    region_description VARCHAR(60) NOT NULL
    
);

CREATE TABLE IF NOT EXISTS mountaineering_data.emergency_contacts (
    emergency_contact_id SERIAL PRIMARY KEY,
    emergency_contact_full_name VARCHAR(60) NOT NULL,
    emergency_contact_phone_number VARCHAR(12) NOT NULL UNIQUE
    
);

CREATE TABLE IF NOT EXISTS mountaineering_data.climb_status_types (
    status_id SERIAL PRIMARY KEY,
    status_label VARCHAR(20) NOT NULL UNIQUE
    
);

CREATE TABLE IF NOT EXISTS mountaineering_data.participation_roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
   
);

CREATE TABLE IF NOT EXISTS mountaineering_data.experience_levels (
    level_id SERIAL PRIMARY KEY,
    level_name VARCHAR(15) NOT NULL UNIQUE
    
);

CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_type (
    equipment_type_id SERIAL PRIMARY KEY,
    equipment_type_description VARCHAR(50) NOT NULL UNIQUE
   
);

CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_description (
    model_name_id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL UNIQUE
    
);
-----
-- Members table (references Emergency Contacts)
CREATE TABLE IF NOT EXISTS mountaineering_data.members (
    member_id SERIAL PRIMARY KEY,
    full_name VARCHAR(60) NOT NULL,
    date_of_birth DATE NOT NULL CHECK (date_of_birth > '2000-01-01'),
    phone_number VARCHAR(12) NOT NULL UNIQUE,  
    email VARCHAR(30) NOT NULL UNIQUE,
    emergency_contact_id INT REFERENCES mountaineering_data.emergency_contacts(emergency_contact_id)
    
);

CREATE TABLE IF NOT EXISTS mountaineering_data.member_experience_history (
    history_id SERIAL PRIMARY KEY,
    member_id INT NOT NULL REFERENCES mountaineering_data.members (member_id),
    level_id INT NOT NULL REFERENCES mountaineering_data.experience_levels (level_id),
    achieved_date DATE NOT NULL CHECK (achieved_date > '2000-01-01'),
    certification_ref VARCHAR(50)
   
);
-- Mountains table (references Regions)
CREATE TABLE IF NOT EXISTS mountaineering_data.mountains (
    mountain_id SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE,
    evaluation_meters INT NOT NULL CHECK (evaluation_meters > 0),
    difficulty_rating INT NOT NULL,
    location_region_id INT NOT NULL REFERENCES mountaineering_data.location_region_description(location_region_id)
   
);

-- Equipment Inventory (references Model and Type)
CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_inventory (
    equipment_id SERIAL PRIMARY KEY,
    model_name_id INT NOT NULL REFERENCES mountaineering_data.equipment_description(model_name_id),
    serial_number VARCHAR(30) NOT NULL UNIQUE,
    equipment_type_id INT NOT NULL REFERENCES mountaineering_data.equipment_type(equipment_type_id),
    last_inspection_date DATE NOT NULL CHECK (last_inspection_date > '2000-01-01')
    
);

CREATE TABLE IF NOT EXISTS mountaineering_data.climbs (
    climb_id SERIAL PRIMARY KEY,
    mountain_id INT NOT NULL REFERENCES mountaineering_data.mountains(mountain_id),
    scheduled_start DATE NOT NULL CHECK (scheduled_start > '2000-01-01'),
    scheduled_end DATE NOT NULL CHECK (scheduled_end > '2000-01-01')
    
);

CREATE TABLE IF NOT EXISTS mountaineering_data.climb_status_log (
    log_id SERIAL PRIMARY KEY,
    climb_id INT NOT NULL REFERENCES mountaineering_data.climbs(climb_id),
    status_id INT NOT NULL REFERENCES mountaineering_data.climb_status_types(status_id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW() CHECK (changed_at > '2000-01-01')
  
);

CREATE TABLE IF NOT EXISTS mountaineering_data.equipment_assignments (
    assignment_id SERIAL PRIMARY KEY,
    equipment_id INT NOT NULL REFERENCES mountaineering_data.equipment_inventory(equipment_id),
    climb_id INT NOT NULL REFERENCES mountaineering_data.climbs(climb_id),
    member_id INT NOT NULL REFERENCES mountaineering_data.members(member_id),
    checkout_date DATE NOT NULL CHECK (checkout_date > '2000-01-01'),
    return_date DATE CHECK (return_date > '2000-01-01')
 
);

CREATE TABLE IF NOT EXISTS mountaineering_data.climb_participants (
    participation_id SERIAL PRIMARY KEY,
    climb_id INT NOT NULL REFERENCES mountaineering_data.climbs(climb_id),
    member_id INT NOT NULL REFERENCES mountaineering_data.members(member_id),
    role_id INT NOT NULL REFERENCES mountaineering_data.participation_roles(role_id),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS mountaineering_data.safety_mentorships (
    mentorship_id SERIAL PRIMARY KEY,
    mentor_id INT REFERENCES mountaineering_data.members (member_id),
    mentee_id INT REFERENCES mountaineering_data.members (member_id) CONSTRAINT no_self_mentoring CHECK (mentee_id <> mentor_id), --Constraint needed to prevent a member from mentoring themselves 
    start_date DATE  NOT NULL CHECK ( start_date > '2000-01-01'), -- I add CHECK (date > '2000-01-01') so that data records cant be before that date.
    end_date DATE  NOT NULL CHECK (end_date > '2000-01-01')
    );

CREATE TABLE IF NOT EXISTS mountaineering_data.member_gear_competency (
    member_id  INT REFERENCES mountaineering_data.members (member_id),
    equipment_type_id INT REFERENCES mountaineering_data.equipment_type (equipment_type_id),
	is_certified BOOLEAN NOT NULL  DEFAULT FALSE,
	PRIMARY KEY (member_id, equipment_type_id)
    );

-- Populate tables
-- 1. Regions & Status Types
INSERT INTO mountaineering_data.location_region_description (region_description) VALUES ('Caucasus Mountains'), ('Swiss Alps');
INSERT INTO mountaineering_data.climb_status_types (status_label) VALUES ('Scheduled'), ('In Progress')
ON CONFLICT (status_label) DO NOTHING;

-- 2. Roles, Experience Levels, & Equipment Meta
INSERT INTO mountaineering_data.participation_roles (role_name) VALUES ('Lead Climber'), ('Safety Officer')
ON CONFLICT (role_name) DO NOTHING;
INSERT INTO mountaineering_data.experience_levels (level_name) VALUES ('Beginner'), ('Expert')
ON CONFLICT (level_name) DO NOTHING;
INSERT INTO mountaineering_data.equipment_type (equipment_type_description) VALUES ('Harness'), ('Crampons')
ON CONFLICT (equipment_type_description) DO NOTHING;
INSERT INTO mountaineering_data.equipment_description (model_name) VALUES ('Petzl Corax'), ('Black Diamond Sabretooth')
ON CONFLICT (model_name) DO NOTHING;

-- 3. Emergency Contacts (Needed for Members)
INSERT INTO mountaineering_data.emergency_contacts (emergency_contact_full_name, emergency_contact_phone_number) 
VALUES ('Sarah Connor', '+15551112222'), ('John Doe', '+15553334444')
ON CONFLICT (emergency_contact_phone_number) DO NOTHING;  -- FIXED foreign key error
-- 4. Mountains (References Regions)
INSERT INTO mountaineering_data.mountains (name, evaluation_meters, difficulty_rating, location_region_id) 
VALUES (
    'Mount Elbrus', 
    5642, 
    3, 
    (SELECT location_region_id FROM mountaineering_data.location_region_description WHERE region_description = 'Caucasus Mountains' LIMIT 1)
) ON CONFLICT (name) DO NOTHING;
-- 5. Members 
INSERT INTO mountaineering_data.members (full_name, date_of_birth, phone_number, email, emergency_contact_id) 
VALUES (
    'Alex Honnold', 
    '2005-06-15', 
    '+15550123456', 
    'alex@test.com', 
    (SELECT emergency_contact_id FROM mountaineering_data.emergency_contacts WHERE emergency_contact_phone_number = '+15551112222' LIMIT 1)
) ON CONFLICT (email) DO NOTHING;

-- 6. Members experience history (references Emergency Contacts)
INSERT INTO mountaineering_data.member_experience_history (member_id, level_id, achieved_date, certification_ref) 
VALUES (
    (SELECT member_id FROM mountaineering_data.members WHERE email = 'alex@test.com' LIMIT 1),
    (SELECT level_id FROM mountaineering_data.experience_levels WHERE level_name = 'Expert' LIMIT 1),
    '2025-05-01', 
    'CERT-99'
)
		ON CONFLICT DO NOTHING;  -- FIXED foreign key error
-- 7. Climbs (References Mountains)
INSERT INTO mountaineering_data.climbs (mountain_id, scheduled_start, scheduled_end) 
VALUES (
    (SELECT mountain_id FROM mountaineering_data.mountains WHERE name = 'Mount Elbrus' LIMIT 1), 
    '2026-06-01', 
    '2026-06-10'
);

-- 8. Equipment Inventory (References Model and Type)
INSERT INTO mountaineering_data.equipment_inventory (model_name_id, serial_number, equipment_type_id, last_inspection_date) 
VALUES (
    (SELECT model_name_id FROM mountaineering_data.equipment_description WHERE model_name = 'Petzl Corax' LIMIT 1), 
    'SN-PTZL-001', 
    (SELECT equipment_type_id FROM mountaineering_data.equipment_type WHERE equipment_type_description = 'Harness' LIMIT 1), 
    '2026-01-10'
)
ON CONFLICT (serial_number) DO NOTHING;  -- FIXED foreign key error and added subquery instead of hardcoding

-- 9. Climb Status Logs & Participants
INSERT INTO mountaineering_data.climb_status_log (climb_id, status_id) 
VALUES (
    (SELECT climb_id FROM mountaineering_data.climbs c 
     JOIN mountaineering_data.mountains m ON c.mountain_id = m.mountain_id 
     WHERE m.name = 'Mount Elbrus' AND c.scheduled_start = '2026-06-01' LIMIT 1),
    (SELECT status_id FROM mountaineering_data.climb_status_types WHERE status_label = 'Scheduled'  LIMIT 1) -- Fix no more hrdcoding
);

INSERT INTO mountaineering_data.climb_participants (climb_id, member_id, role_id) 
VALUES (
    (SELECT climb_id FROM mountaineering_data.climbs c 
     JOIN mountaineering_data.mountains m ON c.mountain_id = m.mountain_id 
     WHERE m.name = 'Mount Elbrus' AND c.scheduled_start = '2026-06-01' LIMIT 1),
    (SELECT member_id FROM mountaineering_data.members WHERE email = 'alex@test.com' LIMIT 1),
    (SELECT role_id FROM mountaineering_data.participation_roles WHERE role_name = 'Lead Climber' LIMIT 1) -- Fix no more hrdcoding
);

-- 10. Gear Assignments & Competency
INSERT INTO mountaineering_data.equipment_assignments (equipment_id, climb_id, member_id, checkout_date) 
VALUES (
    (SELECT equipment_id FROM mountaineering_data.equipment_inventory WHERE serial_number = 'SN-PTZL-001' LIMIT 1),
    (SELECT climb_id FROM mountaineering_data.climbs c 
     JOIN mountaineering_data.mountains m ON c.mountain_id = m.mountain_id 
     WHERE m.name = 'Mount Elbrus' AND c.scheduled_start = '2026-06-01' LIMIT 1),
    (SELECT member_id FROM mountaineering_data.members WHERE email = 'alex@test.com' LIMIT 1),
    '2026-05-30'
) ON CONFLICT DO NOTHING;

INSERT INTO mountaineering_data.member_gear_competency (member_id, equipment_type_id, is_certified) 
VALUES (
    (SELECT member_id FROM mountaineering_data.members WHERE email = 'alex@test.com' LIMIT 1),
    (SELECT equipment_type_id FROM mountaineering_data.equipment_type WHERE equipment_type_description = 'Harness' LIMIT 1), TRUE)
    ON CONFLICT (member_id, equipment_type_id) DO NOTHING;  -- FIXED foreign key error and hardcoding

-- 11. Experience History & Mentorships
INSERT INTO mountaineering_data.member_experience_history (member_id, level_id, achieved_date, certification_ref) 
VALUES (
    (SELECT member_id FROM mountaineering_data.members WHERE email = 'alex@test.com' LIMIT 1),
    (SELECT level_id FROM mountaineering_data.experience_levels WHERE level_name = 'Expert' LIMIT 1),
    '2025-05-01', 
    'CERT-99'
);
INSERT INTO mountaineering_data.safety_mentorships (mentor_id, mentee_id, start_date, end_date) 
VALUES (
    (SELECT member_id FROM mountaineering_data.members WHERE email = 'reinhold@test.com' LIMIT 1), -- The Mentor
    (SELECT member_id FROM mountaineering_data.members WHERE email = 'alex@test.com' LIMIT 1),     -- The Mentee
    '2026-01-01', 
    '2026-12-31'
); -- Fix no hardcoding


-- Add 'record_ts' field FIX - added IF NOT EXISTS for rerunablity

ALTER TABLE  mountaineering_data.members ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.emergency_contacts ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.mountains ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.location_region_description ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.climbs ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.climb_status_log ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.climb_status_types ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.climb_participants ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.participation_roles ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.equipment_inventory ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.equipment_assignments ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.equipment_type ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.equipment_description ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

ALTER TABLE mountaineering_data.member_gear_competency ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.safety_mentorships ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.member_experience_history ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE mountaineering_data.experience_levels ADD COLUMN IF NOT EXISTS record_ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;


