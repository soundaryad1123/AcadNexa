import sys
import os

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_and_root():
    # Health check
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "healthy"

    # Root
    res = client.get("/")
    assert res.status_code == 200
    assert "documentation" in res.json()


def test_auth_login_and_me():
    # 1. Admin Login
    res = client.post("/api/v1/auth/login", json={
        "email": "admin@aitm.edu.in",
        "password": "Password@123"
    })
    # If seeded password was Admin@2026 or Password@123
    if res.status_code != 200:
        res = client.post("/api/v1/auth/login", json={
            "email": "admin@aitm.edu.in",
            "password": "Admin@2026"
        })
    assert res.status_code == 200, f"Login failed: {res.text}"
    data = res.json()
    assert "access_token" in data
    assert data["role"] == "ADMIN"
    admin_token = data["access_token"]

    # 2. Get Me (Admin)
    res = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {admin_token}"})
    assert res.status_code == 200
    assert res.json()["email"] == "admin@aitm.edu.in"

    # 3. Faculty Login
    res = client.post("/api/v1/auth/login", json={
        "email": "priya.sharma@aitm.edu.in",
        "password": "Faculty@123"
    })
    assert res.status_code == 200, f"Faculty login failed: {res.text}"
    faculty_token = res.json()["access_token"]
    assert res.json()["role"] == "FACULTY"

    # 4. Student Login
    res = client.post("/api/v1/auth/login", json={
        "email": "aarav.sharma@aitm.edu.in",
        "password": "Student@123"
    })
    assert res.status_code == 200, f"Student login failed: {res.text}"
    student_token = res.json()["access_token"]
    assert res.json()["role"] == "STUDENT"

    return admin_token, faculty_token, student_token


def test_admin_portal():
    # Login as admin
    res = client.post("/api/v1/auth/login", json={
        "email": "admin@aitm.edu.in",
        "password": "Admin@2026"
    })
    if res.status_code != 200:
        res = client.post("/api/v1/auth/login", json={"email": "admin@aitm.edu.in", "password": "Password@123"})
    admin_token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {admin_token}"}

    # ADM-01: List Users
    res = client.get("/api/v1/admin/users", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) > 0

    # ADM-02: Attendance Summary & Logs
    res = client.get("/api/v1/admin/attendance/summary", headers=headers)
    assert res.status_code == 200

    res = client.get("/api/v1/admin/attendance/logs", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) > 0

    # ADM-03: View Alerts & Post Alert
    res = client.get("/api/v1/admin/alerts", headers=headers)
    assert res.status_code == 200

    res = client.post("/api/v1/admin/alerts", headers=headers, json={
        "title": "Automated System Test Alert",
        "content": "Testing alert broadcast functionality from pytest suite.",
        "category": "ACADEMIC",
        "target_role": "ALL",
        "priority": "HIGH"
    })
    assert res.status_code == 201
    created_alert_id = res.json()["id"]

    # Delete Alert
    res = client.delete(f"/api/v1/admin/alerts/{created_alert_id}", headers=headers)
    assert res.status_code == 204

    # ADM-04: Master Timetable
    res = client.get("/api/v1/admin/timetables", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) > 0


def test_faculty_portal():
    # Login as faculty
    res = client.post("/api/v1/auth/login", json={
        "email": "priya.sharma@aitm.edu.in",
        "password": "Faculty@123"
    })
    faculty_token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {faculty_token}"}

    # FAC-04: Personal Timetable
    res = client.get("/api/v1/faculty/timetable", headers=headers)
    assert res.status_code == 200
    slots = res.json()
    assert len(slots) > 0
    slot_id = slots[0]["id"]
    course_id = slots[0]["course_id"]

    # FAC-01: Session Roster
    res = client.get(f"/api/v1/faculty/sessions/{slot_id}/roster", headers=headers)
    assert res.status_code == 200
    roster_data = res.json()
    assert "students" in roster_data

    # FAC-01: View Session Attendance
    res = client.get(f"/api/v1/faculty/sessions/{slot_id}/attendance", headers=headers)
    assert res.status_code == 200

    # FAC-03: Course Assessments
    res = client.get(f"/api/v1/faculty/courses/{course_id}/assessments", headers=headers)
    assert res.status_code == 200

    # FAC-05: Faculty Alerts
    res = client.get("/api/v1/faculty/alerts", headers=headers)
    assert res.status_code == 200


def test_student_portal():
    # Login as student
    res = client.post("/api/v1/auth/login", json={
        "email": "aarav.sharma@aitm.edu.in",
        "password": "Student@123"
    })
    student_token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {student_token}"}

    # STD-01: Personal Attendance History
    res = client.get("/api/v1/student/attendance", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) > 0

    # STD-01: Attendance Shortage Check
    res = client.get("/api/v1/student/attendance/shortage-check", headers=headers)
    assert res.status_code == 200
    shortage_data = res.json()
    assert "overall_attendance_percentage" in shortage_data
    assert "courses" in shortage_data

    # STD-02: Personalized Timetable
    res = client.get("/api/v1/student/timetable", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) > 0

    # STD-03: Assessments & Progress
    res = client.get("/api/v1/student/assessments", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) > 0

    # STD-04: Student Academic Profile
    res = client.get("/api/v1/student/profile", headers=headers)
    assert res.status_code == 200
    profile = res.json()
    assert profile["roll_number"] == "1AT23CS001"
    assert len(profile["enrolled_courses"]) > 0

    # STD-05: Student Alerts Feed
    res = client.get("/api/v1/student/alerts", headers=headers)
    assert res.status_code == 200


if __name__ == "__main__":
    print("Running FastAPI Backend Automated Test Suite...")
    test_health_and_root()
    print("✓ Health and Root endpoints OK")
    test_auth_login_and_me()
    print("✓ Auth & Profile endpoints OK")
    test_admin_portal()
    print("✓ Admin Portal (AG-01) endpoints OK")
    test_faculty_portal()
    print("✓ Faculty Portal (AG-02) endpoints OK")
    test_student_portal()
    print("✓ Student Portal (AG-03) endpoints OK")
    print("\n========================================================")
    print("ALL FASTAPI BACKEND TEST CASES PASSED SUCCESSFULLY (100%)")
    print("========================================================")
