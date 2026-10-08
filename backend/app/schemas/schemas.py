from datetime import datetime, date, time
from typing import Optional, List, Any
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field, ConfigDict


# =============================================================================
# Auth Schemas
# =============================================================================
class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    college_id: Optional[UUID] = None
    college_slug: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: UUID
    college_id: UUID
    email: str
    full_name: str
    role: str
    department_id: Optional[UUID] = None
    department_name: Optional[str] = None


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    college_id: UUID
    college_name: Optional[str] = None
    department_id: Optional[UUID] = None
    department_name: Optional[str] = None
    department_code: Optional[str] = None
    email: str
    full_name: str
    phone_number: Optional[str] = None
    role: str
    status: str
    avatar_url: Optional[str] = None
    last_login_at: Optional[datetime] = None
    
    # Extra role-specific details
    roll_number: Optional[str] = None
    registration_no: Optional[str] = None
    current_semester: Optional[int] = None
    current_year: Optional[int] = None
    section: Optional[str] = None
    cgpa: Optional[float] = None
    employee_code: Optional[str] = None
    designation: Optional[str] = None
    specialization: Optional[str] = None
    cabin_room: Optional[str] = None


# =============================================================================
# User Management Schemas (ADM-01)
# =============================================================================
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: str = Field(..., pattern="^(ADMIN|FACULTY|STUDENT)$")
    department_id: Optional[UUID] = None
    phone_number: Optional[str] = None
    status: str = "active"
    
    # Optional Student Fields
    roll_number: Optional[str] = None
    registration_no: Optional[str] = None
    current_semester: Optional[int] = 1
    current_year: Optional[int] = 1
    section: Optional[str] = "A"
    batch_year: Optional[str] = "2024-2028"
    guardian_name: Optional[str] = None
    guardian_phone: Optional[str] = None
    
    # Optional Faculty Fields
    employee_code: Optional[str] = None
    designation: Optional[str] = None
    qualification: Optional[str] = None
    specialization: Optional[str] = None
    cabin_room: Optional[str] = None
    
    # Optional Admin Fields
    admin_level: Optional[str] = "SUPER_ADMIN"
    office_location: Optional[str] = None


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    department_id: Optional[UUID] = None
    status: Optional[str] = None
    password: Optional[str] = None


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    college_id: UUID
    department_id: Optional[UUID] = None
    department_name: Optional[str] = None
    email: str
    full_name: str
    phone_number: Optional[str] = None
    role: str
    status: str
    created_at: datetime


# =============================================================================
# Course & Material Schemas
# =============================================================================
class CourseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    college_id: UUID
    department_id: UUID
    code: str
    name: str
    description: Optional[str] = None
    credits: int
    semester: int
    course_type: str
    status: str


class CourseMaterialResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    course_id: UUID
    title: str
    description: Optional[str] = None
    material_type: str
    file_url: str
    file_size_kb: Optional[int] = None
    unit_module: Optional[int] = 1
    created_at: datetime


# =============================================================================
# Timetable Schemas (ADM-04, FAC-04, STD-02)
# =============================================================================
class TimetableCreate(BaseModel):
    department_id: UUID
    course_id: UUID
    faculty_id: UUID
    day_of_week: int = Field(..., ge=1, le=7)
    start_time: time
    end_time: time
    room_number: str
    section: str = "A"
    session_type: str = "THEORY"
    semester: int = Field(..., ge=1, le=12)
    academic_year: str = "2025-2026"


class TimetableUpdate(BaseModel):
    faculty_id: Optional[UUID] = None
    day_of_week: Optional[int] = Field(None, ge=1, le=7)
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    room_number: Optional[str] = None
    section: Optional[str] = None
    session_type: Optional[str] = None


class TimetableResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    college_id: UUID
    department_id: UUID
    department_name: Optional[str] = None
    course_id: UUID
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    faculty_id: UUID
    faculty_name: Optional[str] = None
    day_of_week: int
    day_name: Optional[str] = None
    start_time: time
    end_time: time
    room_number: str
    section: str
    session_type: str
    semester: int
    academic_year: str


# =============================================================================
# Attendance Schemas (ADM-02, FAC-01, FAC-02, STD-01)
# =============================================================================
class StudentAttendanceItem(BaseModel):
    student_id: UUID
    status: str = Field(..., pattern="^(PRESENT|ABSENT|LATE|EXCUSED)$")
    remarks: Optional[str] = None


class SessionAttendanceSubmit(BaseModel):
    attendance_date: date = Field(default_factory=date.today)
    records: List[StudentAttendanceItem]
    verification_mode: str = "PORTAL"


class AttendanceOverrideRequest(BaseModel):
    student_id: UUID
    course_id: UUID
    timetable_id: Optional[UUID] = None
    attendance_date: date = Field(default_factory=date.today)
    status: str = Field(..., pattern="^(PRESENT|ABSENT|LATE|EXCUSED)$")
    remarks: str


class AttendanceRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    student_id: UUID
    student_name: Optional[str] = None
    roll_number: Optional[str] = None
    course_id: UUID
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    timetable_id: Optional[UUID] = None
    attendance_date: date
    status: str
    verification_mode: str
    remarks: Optional[str] = None
    created_at: datetime


class AttendanceSummaryItem(BaseModel):
    department_id: Optional[UUID] = None
    department_name: Optional[str] = None
    attendance_date: Optional[date] = None
    status: str
    count: int


class StudentCourseAttendanceSummary(BaseModel):
    course_id: UUID
    course_code: str
    course_name: str
    total_classes: int
    attended_classes: int
    attendance_percentage: float
    is_shortage: bool  # True if < 75%


class StudentShortageCheckResponse(BaseModel):
    student_id: UUID
    overall_attendance_percentage: float
    has_any_shortage: bool
    courses: List[StudentCourseAttendanceSummary]


# =============================================================================
# Assessment & Grades Schemas (FAC-03, STD-03)
# =============================================================================
class AssessmentCreate(BaseModel):
    student_id: UUID
    course_id: UUID
    assessment_type: str = Field(..., pattern="^(INTERNAL_1|INTERNAL_2|ASSIGNMENT|LAB_VIVA|QUIZ|FINAL_EXAM)$")
    assessment_name: str
    marks_obtained: float
    max_marks: float
    grade_letter: Optional[str] = None
    grade_point: Optional[float] = None
    semester: int
    academic_year: str = "2025-2026"
    remarks: Optional[str] = None


class AssessmentUpdate(BaseModel):
    marks_obtained: Optional[float] = None
    max_marks: Optional[float] = None
    grade_letter: Optional[str] = None
    grade_point: Optional[float] = None
    remarks: Optional[str] = None


class GradeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    student_id: UUID
    student_name: Optional[str] = None
    roll_number: Optional[str] = None
    course_id: UUID
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    faculty_id: UUID
    faculty_name: Optional[str] = None
    assessment_type: str
    assessment_name: str
    marks_obtained: float
    max_marks: float
    grade_letter: Optional[str] = None
    grade_point: Optional[float] = None
    semester: int
    academic_year: str
    remarks: Optional[str] = None
    evaluated_at: datetime


# =============================================================================
# Announcements / Alerts Schemas (ADM-03, FAC-05, STD-05)
# =============================================================================
class AnnouncementCreate(BaseModel):
    title: str
    content: str
    category: str = "GENERAL"
    target_role: str = Field("ALL", pattern="^(ALL|FACULTY|STUDENT|ADMIN)$")
    department_id: Optional[UUID] = None
    priority: str = Field("NORMAL", pattern="^(LOW|NORMAL|HIGH|URGENT)$")
    expires_at: Optional[datetime] = None


class AnnouncementResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    college_id: UUID
    department_id: Optional[UUID] = None
    department_name: Optional[str] = None
    author_id: UUID
    author_name: Optional[str] = None
    title: str
    content: str
    category: str
    target_role: str
    priority: str
    expires_at: Optional[datetime] = None
    created_at: datetime


# =============================================================================
# Academic Calendar Schemas
# =============================================================================
class CalendarEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    college_id: UUID
    event_title: str
    event_type: str
    description: Optional[str] = None
    start_date: date
    end_date: date
    is_holiday: bool
    target_audience: str
