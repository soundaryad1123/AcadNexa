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
        "https://acad-nexa-frontend.vercel.app",
    ]

    @property
    def DATABASE_URL(self) -> str:
        import urllib.parse
        import re

        # Check explicit database URL environment variables (Render / Supabase / Neon / Railway)
        env_url = (
            os.getenv("DATABASE_URL")
            or os.getenv("POSTGRES_URL")
            or os.getenv("SUPABASE_DB_URL")
        )
        if not env_url:
            # Check individual environment variables
            if self.POSTGRES_HOST != "localhost" or (not os.getenv("RENDER") and self.ENVIRONMENT != "production"):
                encoded_password = urllib.parse.quote_plus(self.POSTGRES_PASSWORD)
                env_url = f"postgresql+psycopg2://{self.POSTGRES_USER}:{encoded_password}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
            else:
                encoded_pw = urllib.parse.quote_plus("Soundarya@26")
                env_url = f"postgresql+psycopg2://postgres.ybyitltbfkgephhtwnxw:{encoded_pw}@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?sslmode=require"

        env_url = env_url.strip()

        # Fix known typo in project ref if present
        env_url = env_url.replace("ybyitltbkgephhtwnxw", "ybyitltbfkgephhtwnxw")

        # Replace placeholder password if present
        if "[YOUR-PASSWORD]" in env_url or "YOUR-PASSWORD" in env_url:
            encoded_pw = urllib.parse.quote_plus("Soundarya@26")
            env_url = env_url.replace("[YOUR-PASSWORD]", encoded_pw).replace("YOUR-PASSWORD", encoded_pw)

        # 1. Clean unescaped '@' characters in password
        if env_url.count("@") > 1:
            scheme, rest = env_url.split("://", 1)
            auth_part, host_part = rest.rsplit("@", 1)
            if ":" in auth_part:
                user, password = auth_part.split(":", 1)
                password_encoded = urllib.parse.quote_plus(urllib.parse.unquote_plus(password))
                env_url = f"{scheme}://{user}:{password_encoded}@{host_part}"

        # 2. Direct Supabase domains (db.<ref>.supabase.co) lack IPv4 DNS records on Render.
        # Auto-route to the IPv4-enabled AWS pooler:
        match = re.search(r"db\.([a-z0-9]+)\.supabase\.co", env_url)
        if match:
            ref = match.group(1)
            if ref == "ybyitltbkgephhtwnxw":
                ref = "ybyitltbfkgephhtwnxw"
            pooler_host = "aws-0-ap-south-1.pooler.supabase.com:6543"
            env_url = re.sub(r"db\.[a-z0-9]+\.supabase\.co(?::\d+)?", pooler_host, env_url)
            if f"postgres.{ref}" not in env_url:
                env_url = re.sub(r"://postgres(?:\.[a-z0-9]+)?:", f"://postgres.{ref}:", env_url)

        # 3. If pooler host is present, ensure correct tenant user
        if "pooler.supabase.com" in env_url and "postgres.ybyitltbfkgephhtwnxw" not in env_url:
            env_url = re.sub(r"://postgres(?:\.[a-z0-9]+)?:", "://postgres.ybyitltbfkgephhtwnxw:", env_url)

        # 4. Ensure SSL mode is set for Supabase / Cloud Postgres
        if ".supabase.com" in env_url or ".pooler.supabase.com" in env_url:
            if "sslmode=" not in env_url:
                sep = "&" if "?" in env_url else "?"
                env_url = f"{env_url}{sep}sslmode=require"

        # 5. Normalize dialect for SQLAlchemy
        if env_url.startswith("postgres://"):
            return env_url.replace("postgres://", "postgresql+psycopg2://", 1)
        elif env_url.startswith("postgresql://") and not env_url.startswith("postgresql+psycopg2://"):
            return env_url.replace("postgresql://", "postgresql+psycopg2://", 1)

        return env_url

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="allow"
    )


settings = Settings()
