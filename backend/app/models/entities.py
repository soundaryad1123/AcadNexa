import uuid
from datetime import datetime, date, timezone
from sqlalchemy import (
    Column, String, Boolean, Integer, Numeric, Date as SQLDate,
    DateTime, Time as SQLTime, Text, ForeignKey, UniqueConstraint, Index, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base


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
    users = relationship("User", back_populates="department")
    courses = relationship("Course", back_populates="department")


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    department_id = Column(UUID(as_uuid=True), ForeignKey("departments.id", ondelete="SET NULL"), nullable=True)
    email = Column(String(255), nullable=False)
    password_hash = Column(Text, nullable=False)
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
    department = relationship("Department", back_populates="users")
    admin_profile = relationship("Admin", back_populates="user", uselist=False, cascade="all, delete-orphan")
    faculty_profile = relationship("Faculty", back_populates="user", uselist=False, cascade="all, delete-orphan")
    student_profile = relationship("Student", back_populates="user", uselist=False, cascade="all, delete-orphan")


class Admin(Base):
    __tablename__ = "admins"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    admin_level = Column(String(32), nullable=False, default="SUPER_ADMIN")
    office_location = Column(String(128), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="admin_profile")


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
    hire_date = Column(SQLDate, nullable=False, default=date.today)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("college_id", "employee_code", name="uq_faculty_college_code"),
        Index("idx_faculty_college_dept", "college_id", "department_id"),
    )

    user = relationship("User", back_populates="faculty_profile")
    department = relationship("Department")
    timetables = relationship("Timetable", back_populates="faculty")


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
    admission_date = Column(SQLDate, nullable=False, default=date.today)
    guardian_name = Column(String(150), nullable=True)
    guardian_phone = Column(String(32), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("college_id", "roll_number", name="uq_students_college_roll"),
        UniqueConstraint("college_id", "registration_no", name="uq_students_college_regno"),
        Index("idx_students_college_dept", "college_id", "department_id", "current_semester"),
    )

    user = relationship("User", back_populates="student_profile")
    department = relationship("Department")
    enrollments = relationship("CourseEnrollment", back_populates="student", cascade="all, delete-orphan")
    attendance_records = relationship("Attendance", back_populates="student", cascade="all, delete-orphan")
    grades = relationship("Grade", back_populates="student", cascade="all, delete-orphan")


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

    department = relationship("Department", back_populates="courses")
    enrollments = relationship("CourseEnrollment", back_populates="course", cascade="all, delete-orphan")
    materials = relationship("CourseMaterial", back_populates="course", cascade="all, delete-orphan")
    timetables = relationship("Timetable", back_populates="course", cascade="all, delete-orphan")


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

    student = relationship("Student", back_populates="enrollments")
    course = relationship("Course", back_populates="enrollments")


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

    course = relationship("Course", back_populates="materials")
    uploader = relationship("User")


class AcademicCalendar(Base):
    __tablename__ = "academic_calendar"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    event_title = Column(String(255), nullable=False)
    event_type = Column(String(32), nullable=False)
    description = Column(Text, nullable=True)
    start_date = Column(SQLDate, nullable=False)
    end_date = Column(SQLDate, nullable=False)
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

    author = relationship("User")
    department = relationship("Department")


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

    course = relationship("Course", back_populates="timetables")
    faculty = relationship("Faculty", back_populates="timetables")
    department = relationship("Department")


class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    college_id = Column(UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    timetable_id = Column(UUID(as_uuid=True), ForeignKey("timetable.id", ondelete="SET NULL"), nullable=True)
    attendance_date = Column(SQLDate, nullable=False, default=date.today)
    status = Column(String(20), nullable=False, default="PRESENT")
    marked_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    verification_mode = Column(String(32), nullable=False, default="MANUAL")
    remarks = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("student_id", "course_id", "attendance_date", "timetable_id", name="uq_student_course_date_timetable"),
        Index("idx_attendance_student", "student_id", "course_id", "attendance_date"),
    )

    student = relationship("Student", back_populates="attendance_records")
    course = relationship("Course")
    timetable = relationship("Timetable")
    marker = relationship("User", foreign_keys=[marked_by])


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

    student = relationship("Student", back_populates="grades")
    course = relationship("Course")
    faculty = relationship("Faculty")
