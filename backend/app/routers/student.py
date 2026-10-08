from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.core.dependencies import require_student
from app.models.entities import (
    User, Student, Department, Course, CourseEnrollment,
    Timetable, Attendance, Grade, Announcement
)
from app.schemas.schemas import (
    AttendanceRecordResponse, StudentShortageCheckResponse,
    StudentCourseAttendanceSummary, TimetableResponse,
    GradeResponse, AnnouncementResponse
)

router = APIRouter(prefix="/student", tags=["Student Operations (AG-03)"])

DAY_MAP = {1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday", 6: "Saturday", 7: "Sunday"}


# =============================================================================
# STD-01: Personal Attendance Records & Shortage Check
# =============================================================================
@router.get("/attendance", response_model=List[AttendanceRecordResponse], summary="STD-01: View personal attendance history")
def get_student_attendance_history(
    course_id: Optional[UUID] = Query(None, description="Filter by course"),
    current_student_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    """
    Returns personal attendance log entries for the authenticated student.
    """
    student = db.query(Student).filter(Student.user_id == current_student_user.id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Student profile not found.")
        
    query = db.query(Attendance).filter(Attendance.student_id == student.id)
    if course_id:
        query = query.filter(Attendance.course_id == course_id)
        
    records = query.order_by(Attendance.attendance_date.desc()).all()
    results = []
    for a in records:
        results.append(AttendanceRecordResponse(
            id=a.id,
            student_id=student.id,
            student_name=current_student_user.full_name,
            roll_number=student.roll_number,
            course_id=a.course_id,
            course_code=a.course.code if a.course else None,
            course_name=a.course.name if a.course else None,
            timetable_id=a.timetable_id,
            attendance_date=a.attendance_date,
            status=a.status,
            verification_mode=a.verification_mode,
            remarks=a.remarks,
            created_at=a.created_at,
        ))
    return results


@router.get("/attendance/shortage-check", response_model=StudentShortageCheckResponse, summary="STD-01: Dynamic calculation of attendance % & shortage alerts (< 75%)")
def check_attendance_shortage(
    current_student_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    """
    Computes real-time attendance percentage for all enrolled courses and flags subjects with attendance < 75%.
    """
    student = db.query(Student).filter(Student.user_id == current_student_user.id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Student profile not found.")
        
    enrollments = (
        db.query(CourseEnrollment)
        .filter(
            CourseEnrollment.student_id == student.id,
            CourseEnrollment.status == "ENROLLED"
        )
        .all()
    )
    
    course_summaries = []
    total_all_classes = 0
    total_all_attended = 0
    has_any_shortage = False
    
    for enr in enrollments:
        course = enr.course
        total_classes = (
            db.query(func.count(Attendance.id))
            .filter(
                Attendance.student_id == student.id,
                Attendance.course_id == course.id
            )
            .scalar() or 0
        )
        attended_classes = (
            db.query(func.count(Attendance.id))
            .filter(
                Attendance.student_id == student.id,
                Attendance.course_id == course.id,
                Attendance.status.in_(["PRESENT", "LATE"])
            )
            .scalar() or 0
        )
        
        percentage = round((attended_classes / total_classes * 100), 2) if total_classes > 0 else 100.0
        is_shortage = percentage < 75.0
        if is_shortage:
            has_any_shortage = True
            
        total_all_classes += total_classes
        total_all_attended += attended_classes
        
        course_summaries.append(StudentCourseAttendanceSummary(
            course_id=course.id,
            course_code=course.code,
            course_name=course.name,
            total_classes=total_classes,
            attended_classes=attended_classes,
            attendance_percentage=percentage,
            is_shortage=is_shortage,
        ))
        
    overall_percentage = round((total_all_attended / total_all_classes * 100), 2) if total_all_classes > 0 else 100.0
    
    return StudentShortageCheckResponse(
        student_id=student.id,
        overall_attendance_percentage=overall_percentage,
        has_any_shortage=has_any_shortage,
        courses=course_summaries,
    )


# =============================================================================
# STD-02: Personalized Class & Lab Timetable
# =============================================================================
@router.get("/timetable", response_model=List[TimetableResponse], summary="STD-02: View personal class & lab timetable")
def get_student_timetable(
    current_student_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    """
    Returns weekly scheduled classes and labs for the student's enrolled subjects.
    """
    student = db.query(Student).filter(Student.user_id == current_student_user.id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Student profile not found.")
        
    enrolled_course_ids = [
        enr.course_id for enr in db.query(CourseEnrollment).filter(
            CourseEnrollment.student_id == student.id,
            CourseEnrollment.status == "ENROLLED"
        ).all()
    ]
    
    if not enrolled_course_ids:
        # Fallback to department & semester matching timetable
        slots = (
            db.query(Timetable)
            .filter(
                Timetable.department_id == student.department_id,
                Timetable.semester == student.current_semester
            )
            .order_by(Timetable.day_of_week, Timetable.start_time)
            .all()
        )
    else:
        slots = (
            db.query(Timetable)
            .filter(Timetable.course_id.in_(enrolled_course_ids))
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
            faculty_name=t.faculty.user.full_name if t.faculty and t.faculty.user else None,
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
# STD-03: Assessment Marks & Evaluation Progress
# =============================================================================
@router.get("/assessments", response_model=List[GradeResponse], summary="STD-03: View evaluation marks, exam scores & progress")
def get_student_assessments(
    course_id: Optional[UUID] = Query(None, description="Filter by course"),
    semester: Optional[int] = Query(None, description="Filter by semester"),
    current_student_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    """
    Returns student scores across tests, lab vivas, assignments, and exams.
    """
    student = db.query(Student).filter(Student.user_id == current_student_user.id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Student profile not found.")
        
    query = db.query(Grade).filter(Grade.student_id == student.id)
    if course_id:
        query = query.filter(Grade.course_id == course_id)
    if semester:
        query = query.filter(Grade.semester == semester)
        
    grades = query.order_by(Grade.created_at.desc()).all()
    results = []
    for g in grades:
        results.append(GradeResponse(
            id=g.id,
            student_id=student.id,
            student_name=current_student_user.full_name,
            roll_number=student.roll_number,
            course_id=g.course_id,
            course_code=g.course.code if g.course else None,
            course_name=g.course.name if g.course else None,
            faculty_id=g.faculty_id,
            faculty_name=g.faculty.user.full_name if g.faculty and g.faculty.user else None,
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


# =============================================================================
# STD-04: Academic Profile & Enrolled Courses
# =============================================================================
@router.get("/profile", summary="STD-04: View academic profile & enrolled courses")
def get_student_full_profile(
    current_student_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    """
    Returns complete academic profile, registration info, CGPA, and list of registered courses.
    """
    student = db.query(Student).filter(Student.user_id == current_student_user.id).first()
    if not student:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Student profile not found.")
        
    enrollments = (
        db.query(CourseEnrollment)
        .filter(CourseEnrollment.student_id == student.id)
        .all()
    )
    
    courses_data = []
    for enr in enrollments:
        c = enr.course
        courses_data.append({
            "course_id": c.id,
            "code": c.code,
            "name": c.name,
            "credits": c.credits,
            "semester": c.semester,
            "course_type": c.course_type,
            "enrollment_status": enr.status,
            "academic_year": enr.academic_year,
        })
        
    return {
        "student_id": student.id,
        "user_id": current_student_user.id,
        "full_name": current_student_user.full_name,
        "email": current_student_user.email,
        "phone_number": current_student_user.phone_number,
        "college_id": current_student_user.college_id,
        "department_id": student.department_id,
        "department_name": student.department.name if student.department else None,
        "department_code": student.department.code if student.department else None,
        "roll_number": student.roll_number,
        "registration_no": student.registration_no,
        "current_semester": student.current_semester,
        "current_year": student.current_year,
        "section": student.section,
        "batch_year": student.batch_year,
        "cgpa": float(student.cgpa) if student.cgpa is not None else None,
        "guardian_name": student.guardian_name,
        "guardian_phone": student.guardian_phone,
        "enrolled_courses": courses_data,
    }


# =============================================================================
# STD-05: Department & Campus Alerts Feed
# =============================================================================
@router.get("/alerts", response_model=List[AnnouncementResponse], summary="STD-05: View department and campus announcements feed")
def get_student_alerts(
    current_student_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    """
    Returns announcements targeted to students or all members.
    """
    student = db.query(Student).filter(Student.user_id == current_student_user.id).first()
    dept_id = student.department_id if student else current_student_user.department_id
    
    query = (
        db.query(Announcement)
        .filter(
            Announcement.college_id == current_student_user.college_id,
            Announcement.target_role.in_(["ALL", "STUDENT"])
        )
    )
    if dept_id:
        query = query.filter(
            (Announcement.department_id == None) | (Announcement.department_id == dept_id)
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
