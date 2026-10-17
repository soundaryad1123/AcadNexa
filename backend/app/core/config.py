import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "AcadNexa API"
    PROJECT_VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Environment & Host
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    
    # Database
    POSTGRES_USER: str = "acadnexa_user"
    POSTGRES_PASSWORD: str = "acadnexa_password"
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: str = "5432"
    POSTGRES_DB: str = "acadnexa_db"
    
    # JWT & Security
    SECRET_KEY: str = "acadnexa-super-secret-jwt-key-change-in-production-2026-secure"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    
    # CORS
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8000",
        "https://acad-nexa-frontend.vercel.app",
    ]

    @property
    def DATABASE_URL(self) -> str:
        import urllib.parse

        # Check explicit database URL environment variables (Render / Supabase / Neon / Railway)
        env_url = (
            os.getenv("DATABASE_URL")
            or os.getenv("POSTGRES_URL")
            or os.getenv("SUPABASE_DB_URL")
        )
        if env_url:
            env_url = env_url.strip()
            # If the password in the URI contains an unescaped '@' (resulting in multiple '@' in URL)
            if env_url.count("@") > 1:
                scheme, rest = env_url.split("://", 1)
                auth_part, host_part = rest.rsplit("@", 1)
                if ":" in auth_part:
                    user, password = auth_part.split(":", 1)
                    password_encoded = urllib.parse.quote_plus(urllib.parse.unquote_plus(password))
                    env_url = f"{scheme}://{user}:{password_encoded}@{host_part}"

            # Normalize PostgreSQL dialect for SQLAlchemy
            if env_url.startswith("postgres://"):
                return env_url.replace("postgres://", "postgresql+psycopg2://", 1)
            elif env_url.startswith("postgresql://") and not env_url.startswith("postgresql+psycopg2://"):
                return env_url.replace("postgresql://", "postgresql+psycopg2://", 1)
            return env_url

        # Cloud Production Default (Supabase Mumbai ap-south-1 Connection Pooler)
        if os.getenv("RENDER") or (self.ENVIRONMENT == "production" and self.POSTGRES_HOST == "localhost"):
            encoded_pw = urllib.parse.quote_plus("Soundarya@26")
            return f"postgresql+psycopg2://postgres.ybyitltbkgephhtwnxw:{encoded_pw}@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?sslmode=require"

        # URL-encode the password in case it contains special characters (@, #, $, %, etc.)
        encoded_password = urllib.parse.quote_plus(self.POSTGRES_PASSWORD)
        return f"postgresql+psycopg2://{self.POSTGRES_USER}:{encoded_password}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="allow"
    )


settings = Settings()
