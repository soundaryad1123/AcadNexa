from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_password, create_access_token
from app.core.dependencies import get_current_user
from app.models.entities import User, College, Department, Student, Faculty, Admin
from app.schemas.schemas import LoginRequest, TokenResponse, UserProfileResponse

router = APIRouter(prefix="/auth", tags=["Authentication & Profile"])


@router.post("/login", response_model=TokenResponse, summary="User authentication across all roles")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """
    Authenticate user across all roles (Admin, Faculty, Student) and return JWT Bearer token.
    Updates `last_login_at` upon successful verification.
    """
    query = db.query(User).filter(User.email == payload.email)
    
    # Optional tenant scoping if college_id / college_slug supplied
    if payload.college_id:
        query = query.filter(User.college_id == payload.college_id)
    elif payload.college_slug:
        college = db.query(College).filter(College.slug == payload.college_slug).first()
        if college:
            query = query.filter(User.college_id == college.id)
            
    user = query.first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    
    # Verify password hash
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
        
    if user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account is {user.status}. Please contact institution administrator.",
        )
    
    # Update last login timestamp
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)
    
    # Issue JWT with role and college scope
    token_claims = {
        "user_id": str(user.id),
        "college_id": str(user.college_id),
        "role": user.role,
        "email": user.email,
        "full_name": user.full_name,
        "department_id": str(user.department_id) if user.department_id else None,
    }
    access_token = create_access_token(subject=str(user.id), claims=token_claims)
    
    dept_name = user.department.name if user.department else None
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user_id=user.id,
        college_id=user.college_id,
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        department_id=user.department_id,
        department_name=dept_name,
    )


@router.get("/me", response_model=UserProfileResponse, summary="Current authenticated profile & active session")
def get_me(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns current authenticated profile with college, department, and role-specific metadata.
    """
    college = db.query(College).filter(College.id == current_user.college_id).first()
    college_name = college.name if college else None
    
    department = db.query(Department).filter(Department.id == current_user.department_id).first() if current_user.department_id else None
    department_name = department.name if department else None
    department_code = department.code if department else None
    
    response_data = {
        "id": current_user.id,
        "college_id": current_user.college_id,
        "college_name": college_name,
        "department_id": current_user.department_id,
        "department_name": department_name,
        "department_code": department_code,
        "email": current_user.email,
        "full_name": current_user.full_name,
        "phone_number": current_user.phone_number,
        "role": current_user.role,
        "status": current_user.status,
        "avatar_url": current_user.avatar_url,
        "last_login_at": current_user.last_login_at,
    }
    
    # Enrich with role profile details
    if current_user.role == "STUDENT":
        student = db.query(Student).filter(Student.user_id == current_user.id).first()
        if student:
            response_data.update({
                "roll_number": student.roll_number,
                "registration_no": student.registration_no,
                "current_semester": student.current_semester,
                "current_year": student.current_year,
                "section": student.section,
                "cgpa": float(student.cgpa) if student.cgpa is not None else None,
            })
    elif current_user.role == "FACULTY":
        faculty = db.query(Faculty).filter(Faculty.user_id == current_user.id).first()
        if faculty:
            response_data.update({
                "employee_code": faculty.employee_code,
                "designation": faculty.designation,
                "specialization": faculty.specialization,
                "cabin_room": faculty.cabin_room,
            })
            
    return UserProfileResponse(**response_data)
