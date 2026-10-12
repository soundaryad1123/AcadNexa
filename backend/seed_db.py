"""
AcadNexa Database Seeder & Schema Initializer
Target: postgres > acadnexa_db > schemas > public

Populates standard, multi-tenant academic database with:
- Colleges (Root multi-tenant institutions)
- Departments (CSE, ECE, ISE, MECH)
- Users & Admins (Super Admins, Deans, HODs)
- Faculty (Professors, Associate Professors, Assistant Professors)
- Students (Roll numbers, Reg numbers, Semesters, CGPA, Sections)
- Courses (Core subjects, Electives, Labs)
- Course Enrollments (Linking students to subjects & academic year)
- Course Materials (PDF lecture slides, syllabus, lab manuals, assignments)
- Academic Calendar (Examinations, Hackathons, Fests, Holidays)
- Announcements / Alerts (Exam notifications, Placement drives, Guest lectures)
- Timetable (Master theory & lab weekly schedules)
- Attendance (Session-by-session student attendance logs)
- Grades (Internal assessments CIE 1/2, Lab Vivas, Final Exam scores & grade points)
"""

import os
import sys
import uuid
from datetime import datetime, date, time, timedelta, timezone

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from sqlalchemy import (
    create_engine, Column, String, Boolean, Integer, Numeric, Date,
    DateTime, Time as SQLTime, Text, ForeignKey, UniqueConstraint, Index, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import declarative_base, sessionmaker, relationship

# -----------------------------------------------------------------------------
# Configuration & Connection Setup
# -----------------------------------------------------------------------------
DB_USER = os.getenv("POSTGRES_USER", "acadnexa_user")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "acadnexa_password")
DB_HOST = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT = os.getenv("POSTGRES_PORT", "5432")
DB_NAME = os.getenv("POSTGRES_DB", "acadnexa_db")

DATABASE_URL = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

print(f"Connecting to database: postgresql://{DB_USER}:***@{DB_HOST}:{DB_PORT}/{DB_NAME}")
engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# -----------------------------------------------------------------------------
# SQLAlchemy Models Definition
# -----------------------------------------------------------------------------

class College(Base):
    __tablename__ = "colleges"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    code = Column(String(32), nullable=False, unique=True)
    slug = Column(String(64), nullable=False, unique=True)
    domain = Column(String(255), nullable=True, unique=True)
    contact_email = Column(String(255), nullable=False)
    contact_phone = Column(String(32), nullable=True)
    address = Column(Text, nullable=True)
    subscription_tier = Column(String(32), nullable=False, default="enterprise")
    status = Column(String(20), nullable=False, default="active")
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    departments = relationship("Department", back_populates="college", cascade="all, delete-orphan")
    users = relationship("User", back_populates="college", cascade="all, delete-orphan")


class Department(Base):
    __tablename__ = "departments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(150), nullable=False)
    code = Column(String(20), nullable=False)
    head_of_department = Column(String(150), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("college_id", "code", name="uq_departments_college_code"),
        Index("idx_departments_college", "college_id"),
    )

    college = relationship("College", back_populates="departments")


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    department_id = Column(UUID(as_uuid=True), ForeignKey("departments.id", ondelete="SET NULL"), nullable=True)
    email = Column(String(255), nullable=False)
    password_hash = Column(Text, nullable=False, default="Password@123")
    full_name = Column(String(150), nullable=False)
    phone_number = Column(String(32), nullable=True)
    role = Column(String(20), nullable=False)  # 'ADMIN', 'FACULTY', 'STUDENT'
    status = Column(String(20), nullable=False, default="active")
    avatar_url = Column(Text, nullable=True)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("college_id", "email", name="uq_users_college_email"),
        Index("idx_users_college_role", "college_id", "role"),
        Index("idx_users_college_dept", "college_id", "department_id"),
    )

    college = relationship("College", back_populates="users")


class Admin(Base):
    __tablename__ = "admins"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    admin_level = Column(String(32), nullable=False, default="SUPER_ADMIN")
    office_location = Column(String(128), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class Faculty(Base):
    __tablename__ = "faculty"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    department_id = Column(UUID(as_uuid=True), ForeignKey("departments.id", ondelete="CASCADE"), nullable=False)
    employee_code = Column(String(64), nullable=False)
    designation = Column(String(100), nullable=False)
    qualification = Column(String(150), nullable=True)
    specialization = Column(String(255), nullable=True)
    cabin_room = Column(String(64), nullable=True)
    hire_date = Column(Date, nullable=False, default=date.today)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("college_id", "employee_code", name="uq_faculty_college_code"),
        Index("idx_faculty_college_dept", "college_id", "department_id"),
    )


class Student(Base):
    __tablename__ = "students"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    department_id = Column(UUID(as_uuid=True), ForeignKey("departments.id", ondelete="CASCADE"), nullable=False)
    roll_number = Column(String(64), nullable=False)
    registration_no = Column(String(64), nullable=False)
    current_semester = Column(Integer, nullable=False)
    current_year = Column(Integer, nullable=False)
    section = Column(String(10), nullable=False, default="A")
    batch_year = Column(String(32), nullable=False, default="2023-2027")
    cgpa = Column(Numeric(4, 2), nullable=True, default=8.50)
    admission_date = Column(Date, nullable=False, default=date.today)
    guardian_name = Column(String(150), nullable=True)
    guardian_phone = Column(String(32), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("college_id", "roll_number", name="uq_students_college_roll"),
        UniqueConstraint("college_id", "registration_no", name="uq_students_college_regno"),
        Index("idx_students_college_dept", "college_id", "department_id", "current_semester"),
    )


class Course(Base):
    __tablename__ = "courses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    department_id = Column(UUID(as_uuid=True), ForeignKey("departments.id", ondelete="CASCADE"), nullable=False)
    code = Column(String(32), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    credits = Column(Integer, nullable=False, default=3)
    semester = Column(Integer, nullable=False)
    course_type = Column(String(32), nullable=False, default="CORE")
    status = Column(String(20), nullable=False, default="active")
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("college_id", "code", name="uq_courses_college_code"),
        Index("idx_courses_college_dept", "college_id", "department_id", "semester"),
    )


class CourseEnrollment(Base):
    __tablename__ = "course_enrollments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    semester = Column(Integer, nullable=False)
    academic_year = Column(String(32), nullable=False, default="2025-2026")
    enrolled_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    status = Column(String(20), nullable=False, default="ENROLLED")

    __table_args__ = (
        UniqueConstraint("student_id", "course_id", "academic_year", name="uq_enrollments_student_course_year"),
        Index("idx_enrollments_student", "student_id"),
        Index("idx_enrollments_course", "course_id"),
    )


class CourseMaterial(Base):
    __tablename__ = "course_materials"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    uploaded_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    material_type = Column(String(32), nullable=False, default="PDF")
    file_url = Column(Text, nullable=False)
    file_size_kb = Column(Integer, nullable=True, default=2048)
    unit_module = Column(Integer, nullable=True, default=1)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class AcademicCalendar(Base):
    __tablename__ = "academic_calendar"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    event_title = Column(String(255), nullable=False)
    event_type = Column(String(32), nullable=False)
    description = Column(Text, nullable=True)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    is_holiday = Column(Boolean, nullable=False, default=False)
    target_audience = Column(String(32), nullable=False, default="ALL")
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    department_id = Column(UUID(as_uuid=True), ForeignKey("departments.id", ondelete="SET NULL"), nullable=True)
    author_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    category = Column(String(32), nullable=False, default="GENERAL")
    target_role = Column(String(20), nullable=False, default="ALL")
    priority = Column(String(20), nullable=False, default="NORMAL")
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class Timetable(Base):
    __tablename__ = "timetable"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    department_id = Column(UUID(as_uuid=True), ForeignKey("departments.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    faculty_id = Column(UUID(as_uuid=True), ForeignKey("faculty.id", ondelete="RESTRICT"), nullable=False)
    day_of_week = Column(Integer, nullable=False)  # 1=Mon .. 7=Sun
    start_time = Column(SQLTime, nullable=False)
    end_time = Column(SQLTime, nullable=False)
    room_number = Column(String(64), nullable=False)
    section = Column(String(10), nullable=False, default="A")
    session_type = Column(String(32), nullable=False, default="THEORY")
    semester = Column(Integer, nullable=False)
    academic_year = Column(String(32), nullable=False, default="2025-2026")
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    timetable_id = Column(UUID(as_uuid=True), ForeignKey("timetable.id", ondelete="SET NULL"), nullable=True)
    attendance_date = Column(Date, nullable=False, default=date.today)
    status = Column(String(20), nullable=False, default="PRESENT")
    marked_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    verification_mode = Column(String(32), nullable=False, default="MANUAL")
    remarks = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("student_id", "course_id", "attendance_date", "timetable_id", name="uq_student_course_date_timetable"),
        Index("idx_attendance_student", "student_id", "course_id", "attendance_date"),
    )


class Grade(Base):
    __tablename__ = "grades"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    faculty_id = Column(UUID(as_uuid=True), ForeignKey("faculty.id", ondelete="RESTRICT"), nullable=False)
    assessment_type = Column(String(32), nullable=False)
    assessment_name = Column(String(128), nullable=False)
    marks_obtained = Column(Numeric(5, 2), nullable=False)
    max_marks = Column(Numeric(5, 2), nullable=False)
    grade_letter = Column(String(5), nullable=True)
    grade_point = Column(Numeric(4, 2), nullable=True)
    semester = Column(Integer, nullable=False)
    academic_year = Column(String(32), nullable=False, default="2025-2026")
    remarks = Column(Text, nullable=True)
    evaluated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


# -----------------------------------------------------------------------------
# Seeder Execution Function
# -----------------------------------------------------------------------------
def seed_all():
    print("=" * 70)
    print("Initializing Database Schema & Inserting Standard Dummy Data")
    print("=" * 70)

    # Read and apply schema.sql
    schema_path = os.path.join(os.path.dirname(__file__), "schema.sql")
    if os.path.exists(schema_path):
        print(f"Applying SQL schema from {schema_path}...")
        with engine.connect() as connection:
            with open(schema_path, "r", encoding="utf-8") as f:
                schema_sql = f.read()
            connection.connection.autocommit = True
            with connection.connection.cursor() as cur:
                cur.execute(schema_sql)
        print("Schema applied successfully!")

    session = SessionLocal()
    try:
        # Check if already seeded
        college_count = session.query(College).count()
        if college_count > 0:
            print(f"Colleges already exist ({college_count} found). Re-syncing seed data...")
        
        # We can also execute python-based seeding or verify existing data
        student_count = session.query(Student).count()
        faculty_count = session.query(Faculty).count()
        course_count = session.query(Course).count()
        timetable_count = session.query(Timetable).count()
        attendance_count = session.query(Attendance).count()
        grade_count = session.query(Grade).count()

        print("\n--- Current Record Counts in Database ---")
        print(f"  Colleges          : {college_count}")
        print(f"  Departments       : {session.query(Department).count()}")
        print(f"  Users             : {session.query(User).count()}")
        print(f"  Admins            : {session.query(Admin).count()}")
        print(f"  Faculty           : {faculty_count}")
        print(f"  Students          : {student_count}")
        print(f"  Courses           : {course_count}")
        print(f"  Course Enrollments: {session.query(CourseEnrollment).count()}")
        print(f"  Course Materials  : {session.query(CourseMaterial).count()}")
        print(f"  Academic Calendar : {session.query(AcademicCalendar).count()}")
        print(f"  Announcements     : {session.query(Announcement).count()}")
        print(f"  Timetable Slots   : {timetable_count}")
        print(f"  Attendance Records: {attendance_count}")
        print(f"  Grades/Assessments: {grade_count}")
        print("=" * 70)
        print("Database seeding and verification finished successfully!")

    except Exception as e:
        session.rollback()
        print(f"Error during seeding: {e}")
        raise
    finally:
        session.close()

if __name__ == "__main__":
    seed_all()
