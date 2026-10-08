from datetime import datetime, date, timezone
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.core.security import get_password_hash
from app.core.dependencies import require_admin
from app.models.entities import (
    User, Department, Student, Faculty, Admin,
    Attendance, Timetable, Course, Announcement
)
from app.schemas.schemas import (
    UserCreate, UserUpdate, UserResponse,
    TimetableCreate, TimetableUpdate, TimetableResponse,
    AttendanceRecordResponse, AttendanceSummaryItem,
    AnnouncementCreate, AnnouncementResponse
)

router = APIRouter(prefix="/admin", tags=["Admin Operations (AG-01)"])


# =============================================================================
# ADM-01: User & Profile Management
# =============================================================================
@router.get("/users", response_model=List[UserResponse], summary="ADM-01: Manage campus user directory")
def list_users(
    role: Optional[str] = Query(None, description="Filter by role (ADMIN, FACULTY, STUDENT)"),
    department_id: Optional[UUID] = Query(None, description="Filter by department"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status (active, inactive)"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Returns list of users in the admin's college filtered by role, department, or status.
    """
    query = db.query(User).filter(User.college_id == current_admin.college_id)
    if role:
        query = query.filter(User.role == role.upper())
    if department_id:
        query = query.filter(User.department_id == department_id)
    if status_filter:
        query = query.filter(User.status == status_filter.lower())
        
    users = query.order_by(User.created_at.desc()).all()
    results = []
    for u in users:
        dept_name = u.department.name if u.department else None
        results.append(UserResponse(
            id=u.id,
            college_id=u.college_id,
            department_id=u.department_id,
            department_name=dept_name,
            email=u.email,
            full_name=u.full_name,
            phone_number=u.phone_number,
            role=u.role,
            status=u.status,
            created_at=u.created_at,
        ))
    return results


@router.post("/users", response_model=UserResponse, status_code=status.HTTP_201_CREATED, summary="ADM-01: Onboard new student, faculty, or staff")
def create_user(
    payload: UserCreate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Onboard a new user within the admin's college and creates corresponding profile.
    """
    # Check duplicate email within the college
    existing = db.query(User).filter(
        User.college_id == current_admin.college_id,
        User.email == payload.email
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User with email '{payload.email}' already exists in this institution.",
        )
    
    # Validate department
    if payload.department_id:
        dept = db.query(Department).filter(
            Department.id == payload.department_id,
            Department.college_id == current_admin.college_id
        ).first()
        if not dept:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Selected department does not exist in this college.",
            )
            
    # Create base user
    new_user = User(
        college_id=current_admin.college_id,
        department_id=payload.department_id,
        email=payload.email,
        password_hash=get_password_hash(payload.password),
        full_name=payload.full_name,
        phone_number=payload.phone_number,
        role=payload.role,
        status=payload.status,
    )
    db.add(new_user)
    db.flush()
    
    # Create specific profile based on role
    if payload.role == "STUDENT":
        if not payload.roll_number or not payload.registration_no:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Roll number and registration number are required for student onboarding.",
            )
        if not payload.department_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Department is required for student onboarding.",
            )
        student = Student(
            user_id=new_user.id,
            college_id=current_admin.college_id,
            department_id=payload.department_id,
            roll_number=payload.roll_number,
            registration_no=payload.registration_no,
            current_semester=payload.current_semester or 1,
            current_year=payload.current_year or 1,
            section=payload.section or "A",
            batch_year=payload.batch_year or "2024-2028",
            guardian_name=payload.guardian_name,
            guardian_phone=payload.guardian_phone,
        )
        db.add(student)
        
    elif payload.role == "FACULTY":
        if not payload.employee_code or not payload.designation or not payload.department_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Employee code, designation, and department are required for faculty onboarding.",
            )
        faculty = Faculty(
            user_id=new_user.id,
            college_id=current_admin.college_id,
            department_id=payload.department_id,
            employee_code=payload.employee_code,
            designation=payload.designation,
            qualification=payload.qualification,
            specialization=payload.specialization,
            cabin_room=payload.cabin_room,
        )
        db.add(faculty)
        
    elif payload.role == "ADMIN":
        admin_entry = Admin(
            user_id=new_user.id,
            college_id=current_admin.college_id,
            admin_level=payload.admin_level or "SUPER_ADMIN",
            office_location=payload.office_location,
        )
        db.add(admin_entry)
        
    db.commit()
    db.refresh(new_user)
    
    dept_name = new_user.department.name if new_user.department else None
    return UserResponse(
        id=new_user.id,
        college_id=new_user.college_id,
        department_id=new_user.department_id,
        department_name=dept_name,
        email=new_user.email,
        full_name=new_user.full_name,
        phone_number=new_user.phone_number,
        role=new_user.role,
        status=new_user.status,
        created_at=new_user.created_at,
    )


@router.put("/users/{user_id}", response_model=UserResponse, summary="ADM-01: Update user details or departmental assignment")
def update_user(
    user_id: UUID,
    payload: UserUpdate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Update profile details, departmental assignment, status, or password of an existing user.
    """
    user = db.query(User).filter(
        User.id == user_id,
        User.college_id == current_admin.college_id
    ).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found in this institution.",
        )
        
    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.phone_number is not None:
        user.phone_number = payload.phone_number
    if payload.status is not None:
        user.status = payload.status
    if payload.password is not None:
        user.password_hash = get_password_hash(payload.password)
    if payload.department_id is not None:
        dept = db.query(Department).filter(
            Department.id == payload.department_id,
            Department.college_id == current_admin.college_id
        ).first()
        if not dept:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Department not found in this college.",
            )
        user.department_id = payload.department_id
        
    db.commit()
    db.refresh(user)
    
    dept_name = user.department.name if user.department else None
    return UserResponse(
        id=user.id,
        college_id=user.college_id,
        department_id=user.department_id,
        department_name=dept_name,
        email=user.email,
        full_name=user.full_name,
        phone_number=user.phone_number,
        role=user.role,
        status=user.status,
        created_at=user.created_at,
    )


# =============================================================================
# ADM-02: Attendance Metrics & Real-time Logs
# =============================================================================
@router.get("/attendance/summary", response_model=List[AttendanceSummaryItem], summary="ADM-02: Aggregated campus attendance metrics")
def get_attendance_summary(
    start_date: Optional[date] = Query(None, description="Start date filter"),
    end_date: Optional[date] = Query(None, description="End date filter"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Aggregates attendance counts grouped by department, date, and status.
    """
    query = (
        db.query(
            Student.department_id,
            Department.name.label("department_name"),
            Attendance.attendance_date,
            Attendance.status,
            func.count(Attendance.id).label("count")
        )
        .join(Student, Attendance.student_id == Student.id)
        .join(Department, Student.department_id == Department.id)
        .filter(Attendance.college_id == current_admin.college_id)
    )
    if start_date:
        query = query.filter(Attendance.attendance_date >= start_date)
    if end_date:
        query = query.filter(Attendance.attendance_date <= end_date)
        
    rows = (
        query.group_by(Student.department_id, Department.name, Attendance.attendance_date, Attendance.status)
        .order_by(Attendance.attendance_date.desc())
        .all()
    )
    return [
        AttendanceSummaryItem(
            department_id=r.department_id,
            department_name=r.department_name,
            attendance_date=r.attendance_date,
            status=r.status,
            count=r.count,
        )
        for r in rows
    ]


@router.get("/attendance/logs", response_model=List[AttendanceRecordResponse], summary="ADM-02: Filter real-time campus attendance logs")
def search_attendance_logs(
    attendance_date: Optional[date] = Query(None, description="Filter by date"),
    department_id: Optional[UUID] = Query(None, description="Filter by department"),
    course_id: Optional[UUID] = Query(None, description="Filter by course"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status (PRESENT, ABSENT, LATE)"),
    limit: int = Query(50, ge=1, le=200),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Searches attendance records with joined student and course information.
    """
    query = (
        db.query(Attendance)
        .join(Student, Attendance.student_id == Student.id)
        .filter(Attendance.college_id == current_admin.college_id)
    )
    if attendance_date:
        query = query.filter(Attendance.attendance_date == attendance_date)
    if department_id:
        query = query.filter(Student.department_id == department_id)
    if course_id:
        query = query.filter(Attendance.course_id == course_id)
    if status_filter:
        query = query.filter(Attendance.status == status_filter.upper())
        
    records = query.order_by(Attendance.created_at.desc()).limit(limit).all()
    results = []
    for a in records:
        student_name = a.student.user.full_name if a.student and a.student.user else None
        roll_no = a.student.roll_number if a.student else None
        course_code = a.course.code if a.course else None
        course_name = a.course.name if a.course else None
        
        results.append(AttendanceRecordResponse(
            id=a.id,
            student_id=a.student_id,
            student_name=student_name,
            roll_number=roll_no,
            course_id=a.course_id,
            course_code=course_code,
            course_name=course_name,
            timetable_id=a.timetable_id,
            attendance_date=a.attendance_date,
            status=a.status,
            verification_mode=a.verification_mode,
            remarks=a.remarks,
            created_at=a.created_at,
        ))
    return results


# =============================================================================
# ADM-03: Campus & Department Alerts Broadcasts
# =============================================================================
@router.post("/alerts", response_model=AnnouncementResponse, status_code=status.HTTP_201_CREATED, summary="ADM-03: Publish announcements / alerts")
def publish_alert(
    payload: AnnouncementCreate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Broadcasts a campus-wide or department-specific alert or notification.
    """
    if payload.department_id:
        dept = db.query(Department).filter(
            Department.id == payload.department_id,
            Department.college_id == current_admin.college_id
        ).first()
        if not dept:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Target department does not exist in this college.",
            )
            
    announcement = Announcement(
        college_id=current_admin.college_id,
        department_id=payload.department_id,
        author_id=current_admin.id,
        title=payload.title,
        content=payload.content,
        category=payload.category,
        target_role=payload.target_role,
        priority=payload.priority,
        expires_at=payload.expires_at,
    )
    db.add(announcement)
    db.commit()
    db.refresh(announcement)
    
    dept_name = announcement.department.name if announcement.department else None
    return AnnouncementResponse(
        id=announcement.id,
        college_id=announcement.college_id,
        department_id=announcement.department_id,
        department_name=dept_name,
        author_id=announcement.author_id,
        author_name=current_admin.full_name,
        title=announcement.title,
        content=announcement.content,
        category=announcement.category,
        target_role=announcement.target_role,
        priority=announcement.priority,
        expires_at=announcement.expires_at,
        created_at=announcement.created_at,
    )


@router.get("/alerts", response_model=List[AnnouncementResponse], summary="ADM-03: View all published alerts & broadcasts")
def list_alerts(
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Returns all published alerts in the admin's institution.
    """
    announcements = (
        db.query(Announcement)
        .filter(Announcement.college_id == current_admin.college_id)
        .order_by(Announcement.created_at.desc())
        .all()
    )
    results = []
    for a in announcements:
        dept_name = a.department.name if a.department else None
        author_name = a.author.full_name if a.author else None
        results.append(AnnouncementResponse(
            id=a.id,
            college_id=a.college_id,
            department_id=a.department_id,
            department_name=dept_name,
            author_id=a.author_id,
            author_name=author_name,
            title=a.title,
            content=a.content,
            category=a.category,
            target_role=a.target_role,
            priority=a.priority,
            expires_at=a.expires_at,
            created_at=a.created_at,
        ))
    return results


@router.delete("/alerts/{alert_id}", status_code=status.HTTP_204_NO_CONTENT, summary="ADM-03: Archive / delete active alert")
def delete_alert(
    alert_id: UUID,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Deletes an alert broadcast.
    """
    announcement = db.query(Announcement).filter(
        Announcement.id == alert_id,
        Announcement.college_id == current_admin.college_id
    ).first()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found in this institution.",
        )
    db.delete(announcement)
    db.commit()
    return None


# =============================================================================
# ADM-04: Master Institutional Timetables
# =============================================================================
DAY_MAP = {1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday", 6: "Saturday", 7: "Sunday"}


@router.get("/timetables", response_model=List[TimetableResponse], summary="ADM-04: View master institutional schedule")
def list_timetables(
    department_id: Optional[UUID] = Query(None, description="Filter by department"),
    academic_year: Optional[str] = Query("2025-2026", description="Filter by academic year"),
    semester: Optional[int] = Query(None, description="Filter by semester"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Returns master timetable schedules across the campus.
    """
    query = db.query(Timetable).filter(Timetable.college_id == current_admin.college_id)
    if department_id:
        query = query.filter(Timetable.department_id == department_id)
    if academic_year:
        query = query.filter(Timetable.academic_year == academic_year)
    if semester:
        query = query.filter(Timetable.semester == semester)
        
    slots = query.order_by(Timetable.day_of_week, Timetable.start_time).all()
    results = []
    for t in slots:
        dept_name = t.department.name if t.department else None
        course_code = t.course.code if t.course else None
        course_name = t.course.name if t.course else None
        faculty_name = t.faculty.user.full_name if t.faculty and t.faculty.user else None
        
        results.append(TimetableResponse(
            id=t.id,
            college_id=t.college_id,
            department_id=t.department_id,
            department_name=dept_name,
            course_id=t.course_id,
            course_code=course_code,
            course_name=course_name,
            faculty_id=t.faculty_id,
            faculty_name=faculty_name,
            day_of_week=t.day_of_week,
            day_name=DAY_MAP.get(t.day_of_week, "Unknown"),
            start_time=t.start_time,
            end_time=t.end_time,
            room_number=t.room_number,
            section=t.section,
            session_type=t.session_type,
            semester=t.semester,
            academic_year=t.academic_year,
        ))
    return results


@router.post("/timetables", response_model=TimetableResponse, status_code=status.HTTP_201_CREATED, summary="ADM-04: Create master schedule block")
def create_timetable_slot(
    payload: TimetableCreate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Creates a new timetable slot for classes or labs.
    """
    # Validation
    if payload.end_time <= payload.start_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End time must be after start time.",
        )
        
    course = db.query(Course).filter(
        Course.id == payload.course_id,
        Course.college_id == current_admin.college_id
    ).first()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found.")
        
    faculty = db.query(Faculty).filter(
        Faculty.id == payload.faculty_id,
        Faculty.college_id == current_admin.college_id
    ).first()
    if not faculty:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Faculty member not found.")
        
    new_slot = Timetable(
        college_id=current_admin.college_id,
        department_id=payload.department_id,
        course_id=payload.course_id,
        faculty_id=payload.faculty_id,
        day_of_week=payload.day_of_week,
        start_time=payload.start_time,
        end_time=payload.end_time,
        room_number=payload.room_number,
        section=payload.section,
        session_type=payload.session_type,
        semester=payload.semester,
        academic_year=payload.academic_year,
    )
    db.add(new_slot)
    db.commit()
    db.refresh(new_slot)
    
    dept_name = new_slot.department.name if new_slot.department else None
    faculty_name = faculty.user.full_name if faculty.user else None
    
    return TimetableResponse(
        id=new_slot.id,
        college_id=new_slot.college_id,
        department_id=new_slot.department_id,
        department_name=dept_name,
        course_id=new_slot.course_id,
        course_code=course.code,
        course_name=course.name,
        faculty_id=new_slot.faculty_id,
        faculty_name=faculty_name,
        day_of_week=new_slot.day_of_week,
        day_name=DAY_MAP.get(new_slot.day_of_week, "Unknown"),
        start_time=new_slot.start_time,
        end_time=new_slot.end_time,
        room_number=new_slot.room_number,
        section=new_slot.section,
        session_type=new_slot.session_type,
        semester=new_slot.semester,
        academic_year=new_slot.academic_year,
    )


@router.put("/timetables/{id}", response_model=TimetableResponse, summary="ADM-04: Update room allocation, timing, or instructor")
def update_timetable_slot(
    id: UUID,
    payload: TimetableUpdate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Updates schedule details, timing, or assigned room.
    """
    slot = db.query(Timetable).filter(
        Timetable.id == id,
        Timetable.college_id == current_admin.college_id
    ).first()
    if not slot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Timetable slot not found.")
        
    if payload.faculty_id is not None:
        fac = db.query(Faculty).filter(Faculty.id == payload.faculty_id, Faculty.college_id == current_admin.college_id).first()
        if not fac:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Faculty not found.")
        slot.faculty_id = payload.faculty_id
    if payload.day_of_week is not None:
        slot.day_of_week = payload.day_of_week
    if payload.start_time is not None:
        slot.start_time = payload.start_time
    if payload.end_time is not None:
        slot.end_time = payload.end_time
    if payload.room_number is not None:
        slot.room_number = payload.room_number
    if payload.section is not None:
        slot.section = payload.section
    if payload.session_type is not None:
        slot.session_type = payload.session_type
        
    if slot.end_time <= slot.start_time:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="End time must be after start time.")
        
    db.commit()
    db.refresh(slot)
    
    dept_name = slot.department.name if slot.department else None
    course_code = slot.course.code if slot.course else None
    course_name = slot.course.name if slot.course else None
    faculty_name = slot.faculty.user.full_name if slot.faculty and slot.faculty.user else None
    
    return TimetableResponse(
        id=slot.id,
        college_id=slot.college_id,
        department_id=slot.department_id,
        department_name=dept_name,
        course_id=slot.course_id,
        course_code=course_code,
        course_name=course_name,
        faculty_id=slot.faculty_id,
        faculty_name=faculty_name,
        day_of_week=slot.day_of_week,
        day_name=DAY_MAP.get(slot.day_of_week, "Unknown"),
        start_time=slot.start_time,
        end_time=slot.end_time,
        room_number=slot.room_number,
        section=slot.section,
        session_type=slot.session_type,
        semester=slot.semester,
        academic_year=slot.academic_year,
    )


@router.delete("/timetables/{id}", status_code=status.HTTP_204_NO_CONTENT, summary="ADM-04: Remove scheduled class block")
def delete_timetable_slot(
    id: UUID,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Deletes a scheduled timetable slot.
    """
    slot = db.query(Timetable).filter(
        Timetable.id == id,
        Timetable.college_id == current_admin.college_id
    ).first()
    if not slot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Timetable slot not found.")
    db.delete(slot)
    db.commit()
    return None
