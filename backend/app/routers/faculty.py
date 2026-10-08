from datetime import datetime, date, timezone
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import require_faculty
from app.models.entities import (
    User, Faculty, Student, Course, CourseEnrollment,
    Timetable, Attendance, Grade, Announcement
)
from app.schemas.schemas import (
    TimetableResponse, AttendanceRecordResponse,
    SessionAttendanceSubmit, AttendanceOverrideRequest,
    AssessmentCreate, AssessmentUpdate, GradeResponse,
    AnnouncementResponse
)

router = APIRouter(prefix="/faculty", tags=["Faculty Operations (AG-02)"])

DAY_MAP = {1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday", 6: "Saturday", 7: "Sunday"}


# =============================================================================
# FAC-01 & FAC-02: Session Roster, Digital Attendance & Overrides
# =============================================================================
@router.get("/sessions/{id}/roster", summary="FAC-01: View enrolled student roster for session")
def get_session_roster(
    id: UUID,
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Returns list of enrolled students eligible for attendance in this timetable slot.
    """
    slot = db.query(Timetable).filter(
        Timetable.id == id,
        Timetable.college_id == current_faculty_user.college_id
    ).first()
    if not slot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session timetable slot not found.")
        
    enrollments = (
        db.query(CourseEnrollment)
        .join(Student, CourseEnrollment.student_id == Student.id)
        .join(User, Student.user_id == User.id)
        .filter(
            CourseEnrollment.course_id == slot.course_id,
            CourseEnrollment.status == "ENROLLED"
        )
        .order_by(Student.roll_number)
        .all()
    )
    
    roster = []
    for enr in enrollments:
        student = enr.student
        roster.append({
            "enrollment_id": enr.id,
            "student_id": student.id,
            "user_id": student.user_id,
            "full_name": student.user.full_name,
            "email": student.user.email,
            "roll_number": student.roll_number,
            "registration_no": student.registration_no,
            "section": student.section,
            "semester": student.current_semester,
        })
    return {
        "timetable_id": slot.id,
        "course_id": slot.course_id,
        "course_code": slot.course.code,
        "course_name": slot.course.name,
        "room_number": slot.room_number,
        "session_type": slot.session_type,
        "total_enrolled": len(roster),
        "students": roster,
    }


@router.post("/sessions/{id}/attendance", response_model=List[AttendanceRecordResponse], status_code=status.HTTP_201_CREATED, summary="FAC-01: Record digital class attendance")
def record_session_attendance(
    id: UUID,
    payload: SessionAttendanceSubmit,
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Records attendance batch for all students attending a specific session.
    """
    slot = db.query(Timetable).filter(
        Timetable.id == id,
        Timetable.college_id == current_faculty_user.college_id
    ).first()
    if not slot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session timetable slot not found.")
        
    results = []
    for item in payload.records:
        # Check if record already exists for this student, course, date & slot
        existing = db.query(Attendance).filter(
            Attendance.student_id == item.student_id,
            Attendance.course_id == slot.course_id,
            Attendance.attendance_date == payload.attendance_date,
            Attendance.timetable_id == slot.id,
        ).first()
        
        if existing:
            existing.status = item.status
            existing.marked_by = current_faculty_user.id
            existing.verification_mode = payload.verification_mode
            if item.remarks:
                existing.remarks = item.remarks
            att_obj = existing
        else:
            att_obj = Attendance(
                college_id=current_faculty_user.college_id,
                student_id=item.student_id,
                course_id=slot.course_id,
                timetable_id=slot.id,
                attendance_date=payload.attendance_date,
                status=item.status,
                marked_by=current_faculty_user.id,
                verification_mode=payload.verification_mode,
                remarks=item.remarks,
            )
            db.add(att_obj)
            
        db.flush()
        student = db.query(Student).filter(Student.id == item.student_id).first()
        student_name = student.user.full_name if student and student.user else None
        roll_no = student.roll_number if student else None
        
        results.append(AttendanceRecordResponse(
            id=att_obj.id,
            student_id=att_obj.student_id,
            student_name=student_name,
            roll_number=roll_no,
            course_id=slot.course_id,
            course_code=slot.course.code,
            course_name=slot.course.name,
            timetable_id=slot.id,
            attendance_date=att_obj.attendance_date,
            status=att_obj.status,
            verification_mode=att_obj.verification_mode,
            remarks=att_obj.remarks,
            created_at=att_obj.created_at,
        ))
        
    db.commit()
    return results


@router.get("/sessions/{id}/attendance", response_model=List[AttendanceRecordResponse], summary="FAC-01: View recorded attendance for a session")
def get_session_attendance(
    id: UUID,
    attendance_date: Optional[date] = Query(default_factory=date.today),
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Returns recorded attendance entries for a given session and date.
    """
    slot = db.query(Timetable).filter(
        Timetable.id == id,
        Timetable.college_id == current_faculty_user.college_id
    ).first()
    if not slot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session slot not found.")
        
    records = (
        db.query(Attendance)
        .filter(
            Attendance.timetable_id == slot.id,
            Attendance.attendance_date == attendance_date
        )
        .all()
    )
    
    results = []
    for a in records:
        student_name = a.student.user.full_name if a.student and a.student.user else None
        roll_no = a.student.roll_number if a.student else None
        results.append(AttendanceRecordResponse(
            id=a.id,
            student_id=a.student_id,
            student_name=student_name,
            roll_number=roll_no,
            course_id=slot.course_id,
            course_code=slot.course.code,
            course_name=slot.course.name,
            timetable_id=slot.id,
            attendance_date=a.attendance_date,
            status=a.status,
            verification_mode=a.verification_mode,
            remarks=a.remarks,
            created_at=a.created_at,
        ))
    return results


@router.post("/attendance/override", response_model=AttendanceRecordResponse, summary="FAC-02: Manually override student attendance")
def override_student_attendance(
    payload: AttendanceOverrideRequest,
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Faculty override to manually correct or adjust student attendance record with audit remarks.
    """
    student = db.query(Student).filter(
        Student.id == payload.student_id,
        Student.college_id == current_faculty_user.college_id
    ).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found.")
        
    course = db.query(Course).filter(
        Course.id == payload.course_id,
        Course.college_id == current_faculty_user.college_id
    ).first()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found.")
        
    # Search existing
    existing = db.query(Attendance).filter(
        Attendance.student_id == payload.student_id,
        Attendance.course_id == payload.course_id,
        Attendance.attendance_date == payload.attendance_date,
    )
    if payload.timetable_id:
        existing = existing.filter(Attendance.timetable_id == payload.timetable_id)
        
    record = existing.first()
    if record:
        record.status = payload.status
        record.marked_by = current_faculty_user.id
        record.verification_mode = "MANUAL"
        record.remarks = f"[FACULTY OVERRIDE] {payload.remarks}"
    else:
        record = Attendance(
            college_id=current_faculty_user.college_id,
            student_id=payload.student_id,
            course_id=payload.course_id,
            timetable_id=payload.timetable_id,
            attendance_date=payload.attendance_date,
            status=payload.status,
            marked_by=current_faculty_user.id,
            verification_mode="MANUAL",
            remarks=f"[FACULTY OVERRIDE] {payload.remarks}",
        )
        db.add(record)
        
    db.commit()
    db.refresh(record)
    
    return AttendanceRecordResponse(
        id=record.id,
        student_id=record.student_id,
        student_name=student.user.full_name,
        roll_number=student.roll_number,
        course_id=course.id,
        course_code=course.code,
        course_name=course.name,
        timetable_id=record.timetable_id,
        attendance_date=record.attendance_date,
        status=record.status,
        verification_mode=record.verification_mode,
        remarks=record.remarks,
        created_at=record.created_at,
    )


# =============================================================================
# FAC-03: Assessment Records & Grade Sheet
# =============================================================================
@router.post("/assessments", response_model=GradeResponse, status_code=status.HTTP_201_CREATED, summary="FAC-03: Create evaluation / marks entry")
def create_assessment_entry(
    payload: AssessmentCreate,
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Records student score for an internal test, assignment, lab viva, quiz, or final exam.
    """
    faculty = db.query(Faculty).filter(Faculty.user_id == current_faculty_user.id).first()
    if not faculty:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Faculty profile missing.")
        
    if payload.marks_obtained > payload.max_marks:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Marks obtained ({payload.marks_obtained}) cannot exceed maximum marks ({payload.max_marks})."
        )
        
    student = db.query(Student).filter(
        Student.id == payload.student_id,
        Student.college_id == current_faculty_user.college_id
    ).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found.")
        
    course = db.query(Course).filter(
        Course.id == payload.course_id,
        Course.college_id == current_faculty_user.college_id
    ).first()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found.")
        
    grade = Grade(
        college_id=current_faculty_user.college_id,
        student_id=payload.student_id,
        course_id=payload.course_id,
        faculty_id=faculty.id,
        assessment_type=payload.assessment_type,
        assessment_name=payload.assessment_name,
        marks_obtained=payload.marks_obtained,
        max_marks=payload.max_marks,
        grade_letter=payload.grade_letter,
        grade_point=payload.grade_point,
        semester=payload.semester,
        academic_year=payload.academic_year,
        remarks=payload.remarks,
    )
    db.add(grade)
    db.commit()
    db.refresh(grade)
    
    return GradeResponse(
        id=grade.id,
        student_id=grade.student_id,
        student_name=student.user.full_name,
        roll_number=student.roll_number,
        course_id=course.id,
        course_code=course.code,
        course_name=course.name,
        faculty_id=faculty.id,
        faculty_name=current_faculty_user.full_name,
        assessment_type=grade.assessment_type,
        assessment_name=grade.assessment_name,
        marks_obtained=float(grade.marks_obtained),
        max_marks=float(grade.max_marks),
        grade_letter=grade.grade_letter,
        grade_point=float(grade.grade_point) if grade.grade_point is not None else None,
        semester=grade.semester,
        academic_year=grade.academic_year,
        remarks=grade.remarks,
        evaluated_at=grade.evaluated_at,
    )


@router.get("/courses/{id}/assessments", response_model=List[GradeResponse], summary="FAC-03: View grade sheet for course")
def get_course_assessments(
    id: UUID,
    assessment_type: Optional[str] = Query(None, description="Filter by type (INTERNAL_1, FINAL_EXAM)"),
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Returns complete grade sheet for enrolled students in a given course.
    """
    course = db.query(Course).filter(
        Course.id == id,
        Course.college_id == current_faculty_user.college_id
    ).first()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found.")
        
    query = db.query(Grade).filter(Grade.course_id == course.id)
    if assessment_type:
        query = query.filter(Grade.assessment_type == assessment_type)
        
    grades = query.order_by(Grade.created_at.desc()).all()
    results = []
    for g in grades:
        student_name = g.student.user.full_name if g.student and g.student.user else None
        roll_no = g.student.roll_number if g.student else None
        faculty_name = g.faculty.user.full_name if g.faculty and g.faculty.user else None
        
        results.append(GradeResponse(
            id=g.id,
            student_id=g.student_id,
            student_name=student_name,
            roll_number=roll_no,
            course_id=course.id,
            course_code=course.code,
            course_name=course.name,
            faculty_id=g.faculty_id,
            faculty_name=faculty_name,
            assessment_type=g.assessment_type,
            assessment_name=g.assessment_name,
            marks_obtained=float(g.marks_obtained),
            max_marks=float(g.max_marks),
            grade_letter=g.grade_letter,
            grade_point=float(g.grade_point) if g.grade_point is not None else None,
            semester=g.semester,
            academic_year=g.academic_year,
            remarks=g.remarks,
            evaluated_at=g.evaluated_at,
        ))
    return results


@router.put("/assessments/{record_id}", response_model=GradeResponse, summary="FAC-03: Update / correct entered marks")
def update_assessment_record(
    record_id: UUID,
    payload: AssessmentUpdate,
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Updates or corrects existing grade or score record.
    """
    grade = db.query(Grade).filter(
        Grade.id == record_id,
        Grade.college_id == current_faculty_user.college_id
    ).first()
    if not grade:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grade record not found.")
        
    if payload.marks_obtained is not None:
        if payload.max_marks is not None and payload.marks_obtained > payload.max_marks:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Marks cannot exceed max marks.")
        elif payload.max_marks is None and payload.marks_obtained > float(grade.max_marks):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Marks cannot exceed current max marks.")
        grade.marks_obtained = payload.marks_obtained
        
    if payload.max_marks is not None:
        grade.max_marks = payload.max_marks
    if payload.grade_letter is not None:
        grade.grade_letter = payload.grade_letter
    if payload.grade_point is not None:
        grade.grade_point = payload.grade_point
    if payload.remarks is not None:
        grade.remarks = payload.remarks
        
    grade.evaluated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(grade)
    
    student_name = grade.student.user.full_name if grade.student and grade.student.user else None
    roll_no = grade.student.roll_number if grade.student else None
    faculty_name = grade.faculty.user.full_name if grade.faculty and grade.faculty.user else None
    
    return GradeResponse(
        id=grade.id,
        student_id=grade.student_id,
        student_name=student_name,
        roll_number=roll_no,
        course_id=grade.course_id,
        course_code=grade.course.code,
        course_name=grade.course.name,
        faculty_id=grade.faculty_id,
        faculty_name=faculty_name,
        assessment_type=grade.assessment_type,
        assessment_name=grade.assessment_name,
        marks_obtained=float(grade.marks_obtained),
        max_marks=float(grade.max_marks),
        grade_letter=grade.grade_letter,
        grade_point=float(grade.grade_point) if grade.grade_point is not None else None,
        semester=grade.semester,
        academic_year=grade.academic_year,
        remarks=grade.remarks,
        evaluated_at=grade.evaluated_at,
    )


# =============================================================================
# FAC-04: Personal Teaching Timetable
# =============================================================================
@router.get("/timetable", response_model=List[TimetableResponse], summary="FAC-04: View personal teaching timetable")
def get_faculty_timetable(
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Returns personal teaching weekly schedule for the authenticated faculty member.
    """
    faculty = db.query(Faculty).filter(Faculty.user_id == current_faculty_user.id).first()
    if not faculty:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Faculty profile missing.")
        
    slots = (
        db.query(Timetable)
        .filter(Timetable.faculty_id == faculty.id)
        .order_by(Timetable.day_of_week, Timetable.start_time)
        .all()
    )
    
    results = []
    for t in slots:
        results.append(TimetableResponse(
            id=t.id,
            college_id=t.college_id,
            department_id=t.department_id,
            department_name=t.department.name if t.department else None,
            course_id=t.course_id,
            course_code=t.course.code if t.course else None,
            course_name=t.course.name if t.course else None,
            faculty_id=t.faculty_id,
            faculty_name=current_faculty_user.full_name,
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


# =============================================================================
# FAC-05: Department & Campus Alerts
# =============================================================================
@router.get("/alerts", response_model=List[AnnouncementResponse], summary="FAC-05: View department and campus announcements")
def get_faculty_alerts(
    current_faculty_user: User = Depends(require_faculty),
    db: Session = Depends(get_db),
):
    """
    Returns active announcements targeted to faculty or all members.
    """
    query = (
        db.query(Announcement)
        .filter(
            Announcement.college_id == current_faculty_user.college_id,
            Announcement.target_role.in_(["ALL", "FACULTY"])
        )
    )
    # Include campus-wide or faculty's department
    if current_faculty_user.department_id:
        query = query.filter(
            (Announcement.department_id == None) | (Announcement.department_id == current_faculty_user.department_id)
        )
    else:
        query = query.filter(Announcement.department_id == None)
        
    announcements = query.order_by(Announcement.created_at.desc()).all()
    results = []
    for a in announcements:
        results.append(AnnouncementResponse(
            id=a.id,
            college_id=a.college_id,
            department_id=a.department_id,
            department_name=a.department.name if a.department else None,
            author_id=a.author_id,
            author_name=a.author.full_name if a.author else None,
            title=a.title,
            content=a.content,
            category=a.category,
            target_role=a.target_role,
            priority=a.priority,
            expires_at=a.expires_at,
            created_at=a.created_at,
        ))
    return results
