-- Campus Course & Timetable Manager: full schema (MySQL 8.0, InnoDB, utf8mb4)
-- Run once: mysql -u root -p < schema.sql

CREATE DATABASE IF NOT EXISTS timetable_manager
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE timetable_manager;

-- 1. Departments
CREATE TABLE departments (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(120) NOT NULL UNIQUE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Users (students, lecturers, admins)
CREATE TABLE users (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name      VARCHAR(120) NOT NULL,
  email          VARCHAR(150) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,
  role           ENUM('student','lecturer','admin') NOT NULL DEFAULT 'student',
  identifier     VARCHAR(40) NULL UNIQUE,          -- matric no. or staff no.
  department_id  INT UNSIGNED NULL,
  level          SMALLINT NULL,                    -- 100, 200... (students only)
  is_active      TINYINT(1) NOT NULL DEFAULT 1,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 3. Academic sessions (e.g. 2026/2027 First Semester)
CREATE TABLE academic_sessions (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session     VARCHAR(9) NOT NULL,                 -- '2026/2027'
  semester    ENUM('first','second') NOT NULL,
  is_current  TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_session_sem (session, semester)
) ENGINE=InnoDB;

-- 4. Courses
CREATE TABLE courses (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code           VARCHAR(12) NOT NULL UNIQUE,      -- CSC201
  title          VARCHAR(150) NOT NULL,
  units          TINYINT UNSIGNED NOT NULL,
  level          SMALLINT NOT NULL,
  department_id  INT UNSIGNED NOT NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 5. Lecturer assignment (course can have many lecturers, per session)
CREATE TABLE course_lecturers (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_id   INT UNSIGNED NOT NULL,
  lecturer_id INT UNSIGNED NOT NULL,
  session_id  INT UNSIGNED NOT NULL,
  UNIQUE KEY uq_assign (course_id, lecturer_id, session_id),
  FOREIGN KEY (course_id)   REFERENCES courses(id) ON DELETE CASCADE,
  FOREIGN KEY (lecturer_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (session_id)  REFERENCES academic_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 6. Enrollments (student registers a course in a session)
CREATE TABLE enrollments (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id  INT UNSIGNED NOT NULL,
  course_id   INT UNSIGNED NOT NULL,
  session_id  INT UNSIGNED NOT NULL,
  enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_enroll (student_id, course_id, session_id),
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (course_id)  REFERENCES courses(id) ON DELETE CASCADE,
  FOREIGN KEY (session_id) REFERENCES academic_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7. Venues
CREATE TABLE venues (
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(80) NOT NULL UNIQUE,           -- 'LT1', 'Lab B'
  capacity  SMALLINT UNSIGNED NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

-- 8. Timetable slots
CREATE TABLE timetable_slots (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_id    INT UNSIGNED NOT NULL,
  lecturer_id  INT UNSIGNED NOT NULL,
  venue_id     INT UNSIGNED NOT NULL,
  session_id   INT UNSIGNED NOT NULL,
  day_of_week  TINYINT UNSIGNED NOT NULL,          -- 1=Mon ... 7=Sun
  start_time   TIME NOT NULL,
  end_time     TIME NOT NULL,
  status       ENUM('active','cancelled') NOT NULL DEFAULT 'active',
  created_by   INT UNSIGNED NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CHECK (end_time > start_time),
  INDEX idx_venue_time (venue_id, session_id, day_of_week, start_time),
  INDEX idx_lect_time  (lecturer_id, session_id, day_of_week, start_time),
  FOREIGN KEY (course_id)   REFERENCES courses(id) ON DELETE CASCADE,
  FOREIGN KEY (lecturer_id) REFERENCES users(id) ON DELETE RESTRICT,
  FOREIGN KEY (venue_id)    REFERENCES venues(id) ON DELETE RESTRICT,
  FOREIGN KEY (session_id)  REFERENCES academic_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by)  REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 9. Announcements (per course)
CREATE TABLE announcements (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_id   INT UNSIGNED NOT NULL,
  author_id   INT UNSIGNED NOT NULL,
  title       VARCHAR(150) NOT NULL,
  body        TEXT NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 10. Notifications (in-app)
CREATE TABLE notifications (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  type        ENUM('announcement','timetable_change','system') NOT NULL,
  message     VARCHAR(255) NOT NULL,
  is_read     TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_unread (user_id, is_read),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 11. Password resets
CREATE TABLE password_resets (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  token_hash  CHAR(64) NOT NULL,
  expires_at  DATETIME NOT NULL,
  used        TINYINT(1) NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 12. Audit log (who changed what)
CREATE TABLE audit_log (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NULL,
  action      VARCHAR(60) NOT NULL,                -- 'slot.create'
  entity      VARCHAR(40) NOT NULL,
  entity_id   INT UNSIGNED NULL,
  details     JSON NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Clash check (used in ClashService; :params bound via PDO)
-- Returns rows if the proposed slot overlaps an existing active one
-- by venue OR lecturer in the same session/day.
--
-- SELECT id FROM timetable_slots
-- WHERE session_id = :session AND day_of_week = :day
--   AND status = 'active' AND id <> :ignore_id
--   AND (venue_id = :venue OR lecturer_id = :lecturer)
--   AND start_time < :end AND end_time > :start;
-- ---------------------------------------------------------------
