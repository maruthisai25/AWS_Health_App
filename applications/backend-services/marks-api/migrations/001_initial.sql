-- =============================================================================
-- Initial Database Schema for Marks Management System
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create students table
CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) UNIQUE NOT NULL,
    student_number VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    department VARCHAR(100),
    year_level INTEGER CHECK (year_level >= 1 AND year_level <= 6),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'graduated', 'suspended')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create courses table
CREATE TABLE IF NOT EXISTS courses (
    id SERIAL PRIMARY KEY,
    course_code VARCHAR(20) UNIQUE NOT NULL,
    course_name VARCHAR(200) NOT NULL,
    description TEXT,
    credits INTEGER DEFAULT 3 CHECK (credits > 0),
    instructor_id VARCHAR(255),
    department VARCHAR(100),
    semester VARCHAR(20) CHECK (semester IN ('fall', 'spring', 'summer')),
    year INTEGER CHECK (year >= 2020),
    max_students INTEGER DEFAULT 50,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create assignments table
CREATE TABLE IF NOT EXISTS assignments (
    id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    max_score DECIMAL(5,2) NOT NULL CHECK (max_score > 0),
    due_date TIMESTAMP,
    assignment_type VARCHAR(50) DEFAULT 'assignment' CHECK (assignment_type IN ('assignment', 'quiz', 'exam', 'project', 'participation')),
    weight DECIMAL(3,2) DEFAULT 1.0 CHECK (weight >= 0 AND weight <= 1),
    is_published BOOLEAN DEFAULT false,
    allow_late_submission BOOLEAN DEFAULT false,
    late_penalty_percent DECIMAL(3,2) DEFAULT 0.0 CHECK (late_penalty_percent >= 0 AND late_penalty_percent <= 1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create grades table
CREATE TABLE IF NOT EXISTS grades (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
    assignment_id INTEGER REFERENCES assignments(id) ON DELETE CASCADE,
    score DECIMAL(5,2) CHECK (score >= 0),
    percentage DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN score IS NOT NULL AND (SELECT max_score FROM assignments WHERE id = assignment_id) > 0 
            THEN (score / (SELECT max_score FROM assignments WHERE id = assignment_id)) * 100
            ELSE NULL
        END
    ) STORED,
    letter_grade VARCHAR(2),
    feedback TEXT,
    graded_by VARCHAR(255),
    graded_at TIMESTAMP,
    submission_date TIMESTAMP,
    is_late BOOLEAN DEFAULT false,
    late_days INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'graded', 'returned', 'missing')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, assignment_id)
);

-- Create enrollments table
CREATE TABLE IF NOT EXISTS enrollments (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    enrollment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'dropped', 'completed', 'withdrawn')),
    final_grade VARCHAR(2),
    final_percentage DECIMAL(5,2),
    credits_earned INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, course_id)
);

-- Create grade_categories table for weighted grading
CREATE TABLE IF NOT EXISTS grade_categories (
    id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    weight DECIMAL(3,2) NOT NULL CHECK (weight >= 0 AND weight <= 1),
    drop_lowest INTEGER DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create assignment_categories junction table
CREATE TABLE IF NOT EXISTS assignment_categories (
    assignment_id INTEGER REFERENCES assignments(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES grade_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (assignment_id, category_id)
);

-- Create grade_scales table for letter grade conversion
CREATE TABLE IF NOT EXISTS grade_scales (
    id SERIAL PRIMARY KEY,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    letter_grade VARCHAR(2) NOT NULL,
    min_percentage DECIMAL(5,2) NOT NULL,
    max_percentage DECIMAL(5,2) NOT NULL,
    gpa_points DECIMAL(3,2),
    description VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (min_percentage <= max_percentage)
);

-- Create attendance_integration table (links to attendance system)
CREATE TABLE IF NOT EXISTS attendance_integration (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    attendance_percentage DECIMAL(5,2),
    attendance_points DECIMAL(5,2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, course_id)
);

-- Create audit log table for grade changes
CREATE TABLE IF NOT EXISTS grade_audit_log (
    id SERIAL PRIMARY KEY,
    grade_id INTEGER REFERENCES grades(id) ON DELETE CASCADE,
    old_score DECIMAL(5,2),
    new_score DECIMAL(5,2),
    old_feedback TEXT,
    new_feedback TEXT,
    changed_by VARCHAR(255) NOT NULL,
    change_reason TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Indexes for Performance
-- =============================================================================

-- Students indexes
CREATE INDEX IF NOT EXISTS idx_students_user_id ON students(user_id);
CREATE INDEX IF NOT EXISTS idx_students_student_number ON students(student_number);
CREATE INDEX IF NOT EXISTS idx_students_email ON students(email);
CREATE INDEX IF NOT EXISTS idx_students_department ON students(department);
CREATE INDEX IF NOT EXISTS idx_students_status ON students(status);

-- Courses indexes
CREATE INDEX IF NOT EXISTS idx_courses_course_code ON courses(course_code);
CREATE INDEX IF NOT EXISTS idx_courses_instructor_id ON courses(instructor_id);
CREATE INDEX IF NOT EXISTS idx_courses_department ON courses(department);
CREATE INDEX IF NOT EXISTS idx_courses_semester_year ON courses(semester, year);
CREATE INDEX IF NOT EXISTS idx_courses_status ON courses(status);

-- Assignments indexes
CREATE INDEX IF NOT EXISTS idx_assignments_course_id ON assignments(course_id);
CREATE INDEX IF NOT EXISTS idx_assignments_due_date ON assignments(due_date);
CREATE INDEX IF NOT EXISTS idx_assignments_type ON assignments(assignment_type);
CREATE INDEX IF NOT EXISTS idx_assignments_published ON assignments(is_published);

-- Grades indexes
CREATE INDEX IF NOT EXISTS idx_grades_student_id ON grades(student_id);
CREATE INDEX IF NOT EXISTS idx_grades_assignment_id ON grades(assignment_id);
CREATE INDEX IF NOT EXISTS idx_grades_student_assignment ON grades(student_id, assignment_id);
CREATE INDEX IF NOT EXISTS idx_grades_graded_by ON grades(graded_by);
CREATE INDEX IF NOT EXISTS idx_grades_status ON grades(status);
CREATE INDEX IF NOT EXISTS idx_grades_percentage ON grades(percentage);

-- Enrollments indexes
CREATE INDEX IF NOT EXISTS idx_enrollments_student_id ON enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course_id ON enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_status ON enrollments(status);
CREATE INDEX IF NOT EXISTS idx_enrollments_student_course ON enrollments(student_id, course_id);

-- Grade categories indexes
CREATE INDEX IF NOT EXISTS idx_grade_categories_course_id ON grade_categories(course_id);

-- Attendance integration indexes
CREATE INDEX IF NOT EXISTS idx_attendance_integration_student_course ON attendance_integration(student_id, course_id);

-- Audit log indexes
CREATE INDEX IF NOT EXISTS idx_grade_audit_log_grade_id ON grade_audit_log(grade_id);
CREATE INDEX IF NOT EXISTS idx_grade_audit_log_changed_by ON grade_audit_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_grade_audit_log_changed_at ON grade_audit_log(changed_at);

-- =============================================================================
-- Functions and Triggers
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON students
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_courses_updated_at BEFORE UPDATE ON courses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assignments_updated_at BEFORE UPDATE ON assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_grades_updated_at BEFORE UPDATE ON grades
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_enrollments_updated_at BEFORE UPDATE ON enrollments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_grade_categories_updated_at BEFORE UPDATE ON grade_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate letter grade based on percentage
CREATE OR REPLACE FUNCTION calculate_letter_grade(course_id_param INTEGER, percentage_param DECIMAL)
RETURNS VARCHAR(2) AS $$
DECLARE
    letter_grade_result VARCHAR(2);
BEGIN
    SELECT letter_grade INTO letter_grade_result
    FROM grade_scales
    WHERE course_id = course_id_param
      AND percentage_param >= min_percentage
      AND percentage_param <= max_percentage
    ORDER BY min_percentage DESC
    LIMIT 1;
    
    -- Default grading scale if no custom scale is defined
    IF letter_grade_result IS NULL THEN
        CASE
            WHEN percentage_param >= 97 THEN letter_grade_result := 'A+';
            WHEN percentage_param >= 93 THEN letter_grade_result := 'A';
            WHEN percentage_param >= 90 THEN letter_grade_result := 'A-';
            WHEN percentage_param >= 87 THEN letter_grade_result := 'B+';
            WHEN percentage_param >= 83 THEN letter_grade_result := 'B';
            WHEN percentage_param >= 80 THEN letter_grade_result := 'B-';
            WHEN percentage_param >= 77 THEN letter_grade_result := 'C+';
            WHEN percentage_param >= 73 THEN letter_grade_result := 'C';
            WHEN percentage_param >= 70 THEN letter_grade_result := 'C-';
            WHEN percentage_param >= 67 THEN letter_grade_result := 'D+';
            WHEN percentage_param >= 63 THEN letter_grade_result := 'D';
            WHEN percentage_param >= 60 THEN letter_grade_result := 'D-';
            ELSE letter_grade_result := 'F';
        END CASE;
    END IF;
    
    RETURN letter_grade_result;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically calculate letter grade
CREATE OR REPLACE FUNCTION update_letter_grade()
RETURNS TRIGGER AS $$
DECLARE
    course_id_val INTEGER;
BEGIN
    -- Get course_id from assignment
    SELECT a.course_id INTO course_id_val
    FROM assignments a
    WHERE a.id = NEW.assignment_id;
    
    -- Calculate letter grade if percentage is available
    IF NEW.percentage IS NOT NULL THEN
        NEW.letter_grade := calculate_letter_grade(course_id_val, NEW.percentage);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_grade_letter_grade BEFORE INSERT OR UPDATE ON grades
    FOR EACH ROW EXECUTE FUNCTION update_letter_grade();

-- Function to log grade changes
CREATE OR REPLACE FUNCTION log_grade_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- Only log if score or feedback actually changed
        IF OLD.score IS DISTINCT FROM NEW.score OR OLD.feedback IS DISTINCT FROM NEW.feedback THEN
            INSERT INTO grade_audit_log (
                grade_id, old_score, new_score, old_feedback, new_feedback, 
                changed_by, change_reason
            ) VALUES (
                NEW.id, OLD.score, NEW.score, OLD.feedback, NEW.feedback,
                NEW.graded_by, 'Grade updated'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_grade_changes_trigger AFTER UPDATE ON grades
    FOR EACH ROW EXECUTE FUNCTION log_grade_changes();

-- =============================================================================
-- Views for Common Queries
-- =============================================================================

-- View for student grade summary
CREATE OR REPLACE VIEW student_grade_summary AS
SELECT 
    s.id as student_id,
    s.user_id,
    s.student_number,
    s.first_name,
    s.last_name,
    c.id as course_id,
    c.course_code,
    c.course_name,
    COUNT(g.id) as total_assignments,
    COUNT(CASE WHEN g.status = 'graded' THEN 1 END) as graded_assignments,
    AVG(g.percentage) as average_percentage,
    STRING_AGG(DISTINCT g.letter_grade, ', ' ORDER BY g.letter_grade) as letter_grades
FROM students s
JOIN enrollments e ON s.id = e.student_id
JOIN courses c ON e.course_id = c.id
LEFT JOIN assignments a ON c.id = a.course_id AND a.is_published = true
LEFT JOIN grades g ON s.id = g.student_id AND a.id = g.assignment_id
WHERE e.status = 'active'
GROUP BY s.id, s.user_id, s.student_number, s.first_name, s.last_name, 
         c.id, c.course_code, c.course_name;

-- View for course statistics
CREATE OR REPLACE VIEW course_statistics AS
SELECT 
    c.id as course_id,
    c.course_code,
    c.course_name,
    c.instructor_id,
    COUNT(DISTINCT e.student_id) as enrolled_students,
    COUNT(DISTINCT a.id) as total_assignments,
    COUNT(DISTINCT CASE WHEN a.is_published = true THEN a.id END) as published_assignments,
    AVG(g.percentage) as class_average,
    COUNT(CASE WHEN g.letter_grade IN ('A+', 'A', 'A-') THEN 1 END) as a_grades,
    COUNT(CASE WHEN g.letter_grade IN ('B+', 'B', 'B-') THEN 1 END) as b_grades,
    COUNT(CASE WHEN g.letter_grade IN ('C+', 'C', 'C-') THEN 1 END) as c_grades,
    COUNT(CASE WHEN g.letter_grade IN ('D+', 'D', 'D-') THEN 1 END) as d_grades,
    COUNT(CASE WHEN g.letter_grade = 'F' THEN 1 END) as f_grades
FROM courses c
LEFT JOIN enrollments e ON c.id = e.course_id AND e.status = 'active'
LEFT JOIN assignments a ON c.id = a.course_id
LEFT JOIN grades g ON e.student_id = g.student_id AND a.id = g.assignment_id
WHERE c.status = 'active'
GROUP BY c.id, c.course_code, c.course_name, c.instructor_id;

-- =============================================================================
-- Sample Data (for development/testing)
-- =============================================================================

-- Insert default grade scale for all courses
INSERT INTO grade_scales (course_id, letter_grade, min_percentage, max_percentage, gpa_points, description) 
SELECT 
    c.id,
    grade_data.letter_grade,
    grade_data.min_percentage,
    grade_data.max_percentage,
    grade_data.gpa_points,
    grade_data.description
FROM courses c
CROSS JOIN (
    VALUES 
        ('A+', 97.0, 100.0, 4.0, 'Excellent'),
        ('A', 93.0, 96.9, 4.0, 'Excellent'),
        ('A-', 90.0, 92.9, 3.7, 'Very Good'),
        ('B+', 87.0, 89.9, 3.3, 'Good'),
        ('B', 83.0, 86.9, 3.0, 'Good'),
        ('B-', 80.0, 82.9, 2.7, 'Satisfactory'),
        ('C+', 77.0, 79.9, 2.3, 'Satisfactory'),
        ('C', 73.0, 76.9, 2.0, 'Satisfactory'),
        ('C-', 70.0, 72.9, 1.7, 'Below Average'),
        ('D+', 67.0, 69.9, 1.3, 'Poor'),
        ('D', 63.0, 66.9, 1.0, 'Poor'),
        ('D-', 60.0, 62.9, 0.7, 'Very Poor'),
        ('F', 0.0, 59.9, 0.0, 'Fail')
) AS grade_data(letter_grade, min_percentage, max_percentage, gpa_points, description)
ON CONFLICT DO NOTHING;

-- Create a function to refresh materialized views (if any are added later)
CREATE OR REPLACE FUNCTION refresh_grade_views()
RETURNS void AS $$
BEGIN
    -- Placeholder for refreshing materialized views
    -- REFRESH MATERIALIZED VIEW view_name;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (adjust as needed for your application user)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO marks_app_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO marks_app_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO marks_app_user;

COMMIT;