from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from app.core.config import settings
from app.routers import auth_router, admin_router, faculty_router, student_router

# Initialize FastAPI Application
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.PROJECT_VERSION,
    description="AcadNexa — Multi-Tenant Campus Management & Academic System REST API (FastAPI)",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

# Configure Cross-Origin Resource Sharing (CORS)
# Supports localhost, any Vercel preview/production domain, and custom origins
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://.*",
    allow_origins=settings.BACKEND_CORS_ORIGINS if settings.BACKEND_CORS_ORIGINS else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Global Exception Handlers for Clean & Standard Error Responses
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """
    Standardized 422 Unprocessable Entity error formatter.
    """
    errors = []
    for err in exc.errors():
        field_loc = " -> ".join([str(loc) for loc in err.get("loc", [])])
        errors.append({
            "field": field_loc,
            "message": err.get("msg"),
            "type": err.get("type"),
        })
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "error_code": "VALIDATION_ERROR",
            "message": "Request validation failed",
            "details": errors,
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """
    Catch-all exception handler to ensure CORS headers are preserved even on 500 errors.
    """
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": str(exc),
        },
    )


# Health Check & Root Endpoints
@app.get("/health", tags=["System Health"])
def health_check():
    """
    Liveness and readiness probe endpoint.
    """
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.PROJECT_VERSION,
        "environment": settings.ENVIRONMENT,
    }


@app.get("/health/db", tags=["System Health"])
def db_health_check():
    """
    Verifies live connectivity to PostgreSQL / Supabase.
    """
    from app.core.database import SessionLocal
    from sqlalchemy import text
    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "unhealthy", "database_error": str(e)},
        )
    finally:
        db.close()


@app.get("/", tags=["System Health"])
def root_info():
    """
    Welcome endpoint pointing to API documentation.
    """
    return {
        "message": "Welcome to AcadNexa Multi-Tenant Campus Management API",
        "documentation": "/docs",
        "redoc": "/redoc",
        "api_v1": settings.API_V1_STR,
    }


# Auto-initialize database tables and populate initial root data on startup
@app.on_event("startup")
def startup_init():
    try:
        from app.models.entities import Base, User, College, Department
        from app.core.database import engine, SessionLocal
        from app.core.security import get_password_hash
        import uuid
        
        # 1. Ensure tables exist in database (Supabase)
        Base.metadata.create_all(bind=engine)
        
        # 2. Seed default users if empty
        db = SessionLocal()
        try:
            if db.query(User).count() == 0:
                print("Database empty. Auto-seeding initial colleges and demo users...")
                c_aitm = College(
                    id=uuid.UUID("773013e5-0ce8-4db7-b5af-af50bae06939"),
                    name="Apex Institute of Technology & Management",
                    code="AITM",
                    slug="apex-tech",
                    domain="aitm.edu.in",
                    contact_email="contact@aitm.edu.in",
                    status="active"
                )
                db.add(c_aitm)
                db.flush()
                
                d_cse = Department(
                    id=uuid.UUID("202c1550-5012-475f-a4ac-06fbcb139c93"),
                    college_id=c_aitm.id,
                    name="Computer Science & Engineering",
                    code="CSE",
                    head_of_department="Dr. Arvind Sharma"
                )
                db.add(d_cse)
                db.flush()
                
                u_student = User(
                    id=uuid.UUID("89baf284-a7f5-4727-8dc2-30a3c4ab4a86"),
                    college_id=c_aitm.id,
                    department_id=d_cse.id,
                    email="aarav.sharma@aitm.edu.in",
                    password_hash=get_password_hash("Student@123"),
                    full_name="Aarav Sharma",
                    role="STUDENT",
                    status="active"
                )
                u_faculty = User(
                    id=uuid.UUID("0ce413d1-8815-4239-8919-32ad41121836"),
                    college_id=c_aitm.id,
                    department_id=d_cse.id,
                    email="priya.sharma@aitm.edu.in",
                    password_hash=get_password_hash("Faculty@123"),
                    full_name="Prof. Priya Sharma",
                    role="FACULTY",
                    status="active"
                )
                u_admin = User(
                    id=uuid.UUID("11fa2ab2-d290-412f-a2aa-fccb7e2d6778"),
                    college_id=c_aitm.id,
                    department_id=d_cse.id,
                    email="admin@aitm.edu.in",
                    password_hash=get_password_hash("Admin@2026"),
                    full_name="Prof. Vikramaditya Rao",
                    role="ADMIN",
                    status="active"
                )
                db.add_all([u_student, u_faculty, u_admin])
                db.commit()
                print("Auto-seeded demo users successfully!")
        except Exception as seed_err:
            db.rollback()
            print(f"Seed info: {seed_err}")
        finally:
            db.close()
    except Exception as e:
        print(f"Startup DB init info: {e}")


# Register Modular API Routers under /api/v1
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(admin_router, prefix=settings.API_V1_STR)
app.include_router(faculty_router, prefix=settings.API_V1_STR)
app.include_router(student_router, prefix=settings.API_V1_STR)
