"""
================================================================================
LIKHAYAG MOBILE API - Flask Backend
================================================================================
Complete mobile-focused API with JWT authentication
Merged, cleaned, and organized for mobile applications only

Author: Likhayag Development Team
Version: 3.0 (Mobile-Only - Final)
Last Updated: December 2025
================================================================================
"""

import os
import json
import logging
import random
import smtplib
import string
import uuid
import jwt
import re
import io
from functools import wraps
from datetime import datetime, timedelta, timezone
from email.mime.text import MIMEText
from PIL import Image
import mimetypes
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

# ==================== OPTIONAL IMPORTS ====================
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

try:
    from supabase import create_client, Client
    SUPABASE_AVAILABLE = True
except ImportError:
    SUPABASE_AVAILABLE = False
    create_client = None


# ================================================================================
# SECTION 1: APPLICATION SETUP & CONFIGURATION
# ================================================================================

app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'super_secret_key_change_in_production')

# ---------- JWT Configuration ----------
JWT_SECRET = os.getenv('JWT_SECRET', app.secret_key)
JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION_HOURS = 720  # 30 days

# ---------- CORS Configuration ----------
# Allow all origins for mobile apps
CORS(app, 
     supports_credentials=True,
     origins='*',
     allow_headers=['Content-Type', 'Authorization', 'Accept', 'X-Auth-Token'],
     expose_headers=['X-Auth-Token'],
     methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'])

# ---------- Logging Setup ----------
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ---------- File Upload Configuration ----------
UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', os.path.join(os.getcwd(), 'uploads'))
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'pdf'}
MAX_CONTENT_LENGTH = int(os.getenv('MAX_UPLOAD_BYTES', 5 * 1024 * 1024))
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

# ---------- Supabase Configuration ----------
SUPABASE_URL = os.getenv('SUPABASE_URL', '').strip()
SUPABASE_KEY = os.getenv('SUPABASE_KEY', '').strip()
SUPABASE_RECEIPT_BUCKET = os.getenv('SUPABASE_RECEIPT_BUCKET', 'receipts')
SUPABASE_PROFILE_BUCKET = os.getenv('SUPABASE_PROFILE_BUCKET', 'profile-pictures')

# ---------- Email Configuration ----------
SMTP_EMAIL = os.getenv('SMTP_EMAIL')
SMTP_PASS = os.getenv('SMTP_PASS')
SMTP_SERVER = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', 587))

# ---------- 2FA Configuration ----------
CODE_TTL = int(os.getenv('CODE_TTL', 300))  # 5 minutes
SEND_LIMIT_WINDOW = int(os.getenv('SEND_LIMIT_WINDOW', 3600))  # 1 hour
SEND_LIMIT_COUNT = int(os.getenv('SEND_LIMIT_COUNT', 5))  # Max 5 codes per hour

# ---------- Global Variables ----------
_supabase_client = None


# ================================================================================
# SECTION 2: UTILITY FUNCTIONS
# ================================================================================

def json_response(success, message=None, code=200, **kwargs):
    """Standard JSON response format"""
    payload = {'success': success}
    if message:
        payload['message'] = message
    payload.update(kwargs)
    return jsonify(payload), code


# ================================================================================
# SECTION 3: JWT TOKEN MANAGEMENT
# ================================================================================

def create_token(user_id, email, role):
    """Create JWT token"""
    payload = {
        'user_id': user_id,
        'email': email,
        'role': role,
        'exp': datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS),
        'iat': datetime.utcnow()
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    logger.info(f'✅ Token created for user {user_id} ({email})')
    return token


def decode_token(token):
    """Decode and verify JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning('Token expired')
        return None
    except jwt.InvalidTokenError as e:
        logger.warning(f'Invalid token: {e}')
        return None


def get_token_from_request():
    """Extract JWT token from request headers"""
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        return auth_header.split(' ')[1]
    
    token = request.headers.get('X-Auth-Token')
    if token:
        return token
    
    return None


# ================================================================================
# SECTION 4: AUTHENTICATION DECORATORS
# ================================================================================

def token_required(f):
    """Decorator: Require valid JWT token"""
    @wraps(f)
    def wrap(*args, **kwargs):
        token = get_token_from_request()
        
        if not token:
            return json_response(False, 'Authentication required', 401)
        
        payload = decode_token(token)
        if not payload:
            return json_response(False, 'Invalid or expired token', 401)
        
        request.user_data = payload
        return f(*args, **kwargs)
    
    return wrap


def admin_required(f):
    """Decorator: Require admin role"""
    @wraps(f)
    def wrap(*args, **kwargs):
        token = get_token_from_request()
        
        if not token:
            return json_response(False, 'Authentication required', 401)
        
        payload = decode_token(token)
        if not payload:
            return json_response(False, 'Invalid token', 401)
        
        role = (payload.get('role') or '').lower()
        if role not in ('admin', 'administrator', 'superuser'):
            return json_response(False, 'Admin access required', 403)
        
        request.user_data = payload
        return f(*args, **kwargs)
    
    return wrap
# ================================================================================
# SECTION 5: SUPABASE DATABASE HELPERS
# ================================================================================

def get_supabase():
    """
    Get or create Supabase client singleton
    
    Returns:
        Client: Supabase client instance
    
    Raises:
        RuntimeError: If Supabase not available or not configured
    """
    global _supabase_client
    if _supabase_client is not None:
        return _supabase_client
    if not SUPABASE_AVAILABLE or not create_client:
        raise RuntimeError('Supabase library not available')
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise RuntimeError('Supabase URL/KEY not configured')
    _supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
    logger.info('✅ Supabase client initialized')
    return _supabase_client


def safe_execute(query, operation_name='database operation'):
    """
    Execute Supabase query with comprehensive error handling
    
    Args:
        query: Supabase query object
        operation_name (str): Description of operation for logging
    
    Returns:
        tuple: (success: bool, data: any, error: str)
    """
    try:
        response = query.execute()
        if hasattr(response, 'error') and response.error:
            logger.error(f"{operation_name} failed: {response.error}")
            return False, None, str(response.error)
        data = getattr(response, 'data', None)
        return True, data, None
    except Exception as e:
        logger.exception(f"{operation_name} exception: {e}")
        return False, None, str(e)


def fetch_one(table_name: str, **filters):
    """
    Fetch single record from table by filters
    
    Args:
        table_name (str): Name of database table
        **filters: Column=value filters
    
    Returns:
        dict: Record if found, None otherwise
    """
    try:
        sb = get_supabase()
        query = sb.table(table_name).select('*')
        for k, v in filters.items():
            query = query.eq(k, v)
        success, data, _ = safe_execute(query.limit(1), f'fetch_one({table_name})')
        if success and data and len(data) > 0:
            return data[0]
        return None
    except Exception as e:
        logger.exception(f'fetch_one error: {e}')
        return None
# ================================================================================
# SECTION 6: FILE UPLOAD HELPERS
# ================================================================================

def allowed_file(filename):
    """
    Check if file extension is allowed
    
    Args:
        filename (str): Filename to check
    
    Returns:
        bool: True if extension is allowed
    """
    if not filename:
        return False
    ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
    return ext in ALLOWED_EXTENSIONS


def save_uploaded_file(file_storage, bucket_name):
    """
    Save uploaded file to Supabase storage with unique filename
    
    Args:
        file_storage: FileStorage object from request
        bucket_name (str): Supabase storage bucket name
    
    Returns:
        str: Unique filename in storage
    
    Raises:
        ValueError: If no file or invalid file type
    """
    if not file_storage or file_storage.filename == '':
        raise ValueError("No file provided")
    filename = secure_filename(file_storage.filename)
    if not allowed_file(filename):
        raise ValueError("File type not allowed")
    
    unique = f"{uuid.uuid4().hex}_{filename}"
    
    try:
        sb = get_supabase()
        file_content = file_storage.read()
        sb.storage.from_(bucket_name).upload(unique, file_content)
        logger.info(f'✅ File uploaded: {unique}')
        return unique
    except Exception as e:
        logger.exception(f"Failed to upload file: {e}")
        raise


def get_receipt_url(filename, expires_seconds=3600):
    """
    Get signed URL for file in receipt bucket
    
    Args:
        filename (str): Filename in storage
        expires_seconds (int): URL expiration time
    
    Returns:
        str: Signed URL or None if failed
    """
    if not filename:
        return None
    try:
        sb = get_supabase()
        response = sb.storage.from_(SUPABASE_RECEIPT_BUCKET).create_signed_url(filename, expires_seconds)
        return response.get('signedURL')
    except Exception as e:
        logger.warning(f"Failed to get signed URL: {e}")
        return None


# ================================================================================
# SECTION 7: EMAIL FUNCTIONS
# ================================================================================

def send_via_smtp(recipient_email, subject, html):
    """
    Send email via SMTP
    
    Args:
        recipient_email (str): Recipient email address
        subject (str): Email subject
        html (str): HTML email body
    
    Returns:
        bool: True if sent successfully
    """
    from_addr = SMTP_EMAIL or 'no-reply@example.com'
    msg = MIMEText(html, _subtype='html')
    msg['Subject'] = subject
    msg['From'] = from_addr
    msg['To'] = recipient_email

    if not SMTP_EMAIL or not SMTP_PASS:
        logger.warning('No SMTP credentials configured')
        return False

    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=15)
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SMTP_EMAIL, SMTP_PASS)
        server.sendmail(from_addr, [recipient_email], msg.as_string())
        server.quit()
        logger.info(f'✅ Email sent to {recipient_email}')
        return True
    except Exception as e:
        logger.exception(f'SMTP failed: {e}')
        return False


def send_otp_email(recipient_email, code):
    """
    Send OTP verification email with branded template
    
    Args:
        recipient_email (str): Recipient email address
        code (str): 6-digit verification code
    
    Returns:
        bool: True if sent successfully
    """
    subject = 'Your Likhayag Verification Code'
    html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #059669, #064e3b); padding: 30px; border-radius: 10px; text-align: center;">
            <h2 style="color: white; margin: 0;">Likhayag Verification</h2>
        </div>
        <div style="padding: 30px; background: #f9fafb; border-radius: 10px; margin-top: 20px;">
            <p style="font-size: 16px; color: #374151;">Your verification code is:</p>
            <div style="background: white; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
                <h1 style="color: #059669; font-family: monospace; letter-spacing: 3px; margin: 0;">{code}</h1>
            </div>
            <p style="font-size: 14px; color: #6b7280;">This code will expire in {int(CODE_TTL/60)} minutes.</p>
            <p style="font-size: 12px; color: #9ca3af; margin-top: 20px;">If you didn't request this code, please ignore this email.</p>
        </div>
    </body>
    </html>
    """
    return send_via_smtp(recipient_email, subject, html)


# ================================================================================
# SECTION 8: 2FA CODE MANAGEMENT
# ================================================================================

def store_code(email, code, user_id=None):
    """
    Store 2FA verification code in database
    
    Args:
        email (str): User email
        code (str): 6-digit verification code
        user_id: Optional user ID
    
    Returns:
        bool: True if stored successfully
    """
    try:
        email = email.strip().lower()
        sb = get_supabase()
        expires = datetime.now(timezone.utc) + timedelta(seconds=CODE_TTL)
        payload = {
            'user_id': user_id,
            'email': email,
            'code': code.upper(),
            'expires_at': expires.isoformat(),
        }
        success, _, _ = safe_execute(sb.table('user_2fa_codes').insert(payload), 'store_code')
        return bool(success)
    except Exception as e:
        logger.exception(f'store_code exception: {e}')
        return False


def get_stored_code(email):
    """
    Retrieve valid 2FA code for email
    
    Args:
        email (str): User email
    
    Returns:
        str: Valid code if found and not expired, None otherwise
    """
    try:
        email = email.strip().lower()
        sb = get_supabase()
        query = sb.table('user_2fa_codes').select('*').eq('email', email).order('id', desc=True).limit(1)
        success, data, _ = safe_execute(query, 'get_stored_code')
        if not success or not data:
            return None
        
        row = data[0]
        expires_at = row.get('expires_at')
        
        # Parse expiration datetime
        if isinstance(expires_at, str):
            expires_dt = datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
        elif isinstance(expires_at, datetime):
            expires_dt = expires_at
        else:
            return None
            
        if expires_dt.tzinfo is None:
            expires_dt = expires_dt.replace(tzinfo=timezone.utc)
            
        # Check if expired
        if datetime.now(timezone.utc) > expires_dt:
            return None
            
        return (row.get('code') or '').strip().upper() or None
    except Exception as e:
        logger.exception(f'get_stored_code exception: {e}')
        return None


def delete_stored_code(email):
    """
    Delete all 2FA codes for email
    
    Args:
        email (str): User email
    
    Returns:
        bool: True if deleted successfully
    """
    try:
        email = email.strip().lower()
        sb = get_supabase()
        success, _, _ = safe_execute(sb.table('user_2fa_codes').delete().eq('email', email), 'delete_stored_code')
        return bool(success)
    except Exception:
        return False


def can_send_code(email):
    """
    Check if user can send another 2FA code (rate limiting)
    
    Args:
        email (str): User email
    
    Returns:
        bool: True if user can send another code
    """
    now_ts = int(datetime.now(timezone.utc).timestamp())
    if not hasattr(app, '_send_hist'):
        app._send_hist = {}
    history = app._send_hist.get(email, [])
    history = [t for t in history if now_ts - t < SEND_LIMIT_WINDOW]
    if len(history) >= SEND_LIMIT_COUNT:
        app._send_hist[email] = history
        return False
    history.append(now_ts)
    app._send_hist[email] = history
    return True


# ================================================================================
# SECTION 9: AUTHENTICATION ENDPOINTS
# ================================================================================

@app.route('/api/login', methods=['POST'])
def api_login():
    """
    User login endpoint
    
    Request Body:
        {
            "email": "user@gmail.com",
            "password": "password123"
        }
    
    Response:
        {
            "success": true,
            "message": "Login successful",
            "token": "jwt_token_here",
            "user": {
                "id": 1,
                "name": "John Doe",
                "email": "user@gmail.com",
                "role": "user"
            }
        }
    """
    data = request.get_json(silent=True) or request.form.to_dict()
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    logger.info(f'🔐 Login attempt: {email}')

    if not email or not password:
        return json_response(False, "Email and password required", 400)

    try:
        sb = get_supabase()
        query = sb.table('users').select('*').eq('email', email).limit(1)
        success, user_data, _ = safe_execute(query, 'api_login')
        
        if not success or not user_data:
            return json_response(False, "Invalid credentials", 401)
        
        user = user_data[0]
        
        if not check_password_hash(user.get("password_hash", ""), password):
            return json_response(False, "Invalid credentials", 401)

        role = (user.get("role") or "user").strip().lower()
        token = create_token(user['id'], user['email'], role)
        
        logger.info(f'✅ Login successful: {email}')
        return jsonify({
            "success": True,
            "message": "Login successful",
            "token": token,
            "user": {
                "id": user["id"],
                "name": user.get("display_name") or user.get('first_name', ''),
                "email": user.get("email"),
                "role": role
            }
        }), 200
        
    except Exception as e:
        logger.exception('Login error')
        return json_response(False, "Server error", 500)


@app.route('/api/signup', methods=['POST'])
def api_signup():
    """
    User signup endpoint with 2FA verification
    
    Request Body (without code - creates unverified account):
        {
            "first_name": "John",
            "last_name": "Doe",
            "middle_name": "M",  // optional
            "suffix": "Jr",      // optional
            "email": "user@gmail.com",
            "password": "password123!",
            "confirmPassword": "password123!",
            "role": "user"       // optional, defaults to "user"
        }
    
    Request Body (with code - creates verified account and returns token):
        {
            "first_name": "John",
            "last_name": "Doe",
            "email": "user@gmail.com",
            "password": "password123!",
            "confirmPassword": "password123!",
            "code": "ABC123"     // 2FA verification code
        }
    
    Response (without code):
        {
            "success": true,
            "message": "Account created. Please verify your email.",
            "user_id": 1
        }
    
    Response (with code):
        {
            "success": true,
            "message": "Account created successfully",
            "token": "jwt_token_here",
            "user": {...}
        }
    """
    data = request.get_json(silent=True) or request.form.to_dict()
    
    first = (data.get('first_name') or '').strip()
    middle = (data.get('middle_name') or '').strip()
    last = (data.get('last_name') or '').strip()
    suffix = (data.get('suffix') or '').strip()
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''
    confirm_password = data.get('confirmPassword') or ''
    code = (data.get('code') or '').strip().upper()
    role = (data.get('role') or 'user').strip().lower()
    
    logger.info(f'📝 Signup attempt: {email}')
    
    # Validation
    if not all([email, password, first, last]):
        return json_response(False, 'Missing required fields', 400)
    
    if not email.endswith('@gmail.com') and email != 'admin@admin.com':
        return json_response(False, 'Email must be Gmail', 400)
    
    if len(password) < 8:
        return json_response(False, 'Password must be 8+ characters', 400)
    
    if password != confirm_password:
        return json_response(False, 'Passwords do not match', 400)
    
    if not re.search(r'\d', password):
        return json_response(False, 'Password needs a number', 400)
    
    if not re.search(r'[!@#$%^&*()_\-+={[\]}\|\\:;"\'<>,.?/]', password):
        return json_response(False, 'Password needs special character', 400)
    
    try:
        sb = get_supabase()
        
        # Check existing
        existing = sb.table('users').select('id').eq('email', email).limit(1)
        success, existing_data, _ = safe_execute(existing, 'check_existing')
        
        if success and existing_data:
            return json_response(False, 'Email already registered', 409)
        
        # Build display name
        display_name = first
        if middle:
            display_name += f" {middle}"
        display_name += f" {last}"
        if suffix:
            display_name += f", {suffix}"
        
        # With code - verified signup
        if code:
            stored = get_stored_code(email)
            if not stored or stored != code:
                return json_response(False, "Invalid code", 400)
            
            delete_stored_code(email)
            
            user_payload = {
                'first_name': first,
                'middle_name': middle or None,
                'last_name': last,
                'suffix': suffix or None,
                'display_name': display_name.strip(),
                'email': email,
                'password_hash': generate_password_hash(password),
                'two_fa_verified': True,
                'role': role,
            }
            
            success, created_data, error = safe_execute(
                sb.table('users').insert(user_payload),
                'create_user'
            )
            
            if not success or not created_data:
                return json_response(False, 'Failed to create account', 500)
            
            user = created_data[0]
            token = create_token(user['id'], user['email'], role)
            
            logger.info(f'✅ Signup successful: {email}')
            return jsonify({
                "success": True,
                "message": "Account created",
                "token": token,
                "user": {
                    "id": user["id"],
                    "name": user.get("display_name"),
                    "email": user.get("email"),
                    "role": role
                }
            }), 201
        
        # Without code - unverified
        user_payload = {
            'first_name': first,
            'middle_name': middle or None,
            'last_name': last,
            'suffix': suffix or None,
            'display_name': display_name.strip(),
            'email': email,
            'password_hash': generate_password_hash(password),
            'two_fa_verified': False,
            'role': role,
        }
        
        success, created_data, error = safe_execute(
            sb.table('users').insert(user_payload),
            'create_user'
        )
        
        if not success:
            return json_response(False, 'Failed to create account', 500)
        
        return json_response(
            True, 
            'Account created. Verify email.', 
            201, 
            user_id=created_data[0].get('id') if created_data else None
        )
        
    except Exception as e:
        logger.exception('Signup error')
        return json_response(False, 'Server error', 500)


@app.route('/api/logout', methods=['GET', 'POST'])
def api_logout():
    """
    Logout endpoint (token handled client-side)
    
    Response:
        {
            "success": true,
            "message": "Logged out"
        }
    """
    return json_response(True, "Logged out")


# ================================================================================
# SECTION 10: 2FA ENDPOINTS
# ================================================================================

@app.route('/api/2fa/send', methods=['POST'])
def api_2fa_send():
    """
    Send 2FA verification code to email
    
    Request Body:
        {
            "email": "user@gmail.com"
        }
    
    Response:
        {
            "success": true,
            "message": "Code sent"
        }
    """
    data = request.get_json(silent=True) or request.form.to_dict()
    email = (data.get('email') or '').strip().lower()
    
    if not email:
        return json_response(False, "Email required", 400)
    
    if not email.endswith('@gmail.com') and email != 'admin@admin.com':
        return json_response(False, "Email must be Gmail", 400)
    
    if not can_send_code(email):
        return json_response(False, "Too many requests", 429)
    
    code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    
    if not store_code(email, code):
        return json_response(False, 'Failed to store code', 500)
    
    if not send_otp_email(email, code):
        delete_stored_code(email)
        return json_response(False, 'Failed to send email', 500)
    
    logger.info(f'📧 2FA sent to {email}')
    return json_response(True, 'Code sent', 200)


@app.route('/api/2fa/verify', methods=['POST'])
def api_2fa_verify():
    """Verify 2FA code"""
    data = request.get_json(silent=True) or request.form.to_dict()
    code = str(data.get('code') or '').strip().upper()
    email = (data.get('email') or '').strip().lower()
    
    if not code or not email:
        return json_response(False, 'Missing email or code', 400)
    
    stored = get_stored_code(email)
    if not stored or stored != code:
        return json_response(False, 'Invalid code', 400)
    
    delete_stored_code(email)
    
    try:
        sb = get_supabase()
        query = sb.table('users').select('*').eq('email', email).limit(1)
        success, user_data, _ = safe_execute(query, 'get_user')
        
        if not success or not user_data:
            return json_response(False, 'User not found', 404)
        
        user = user_data[0]
        
        # Mark verified
        safe_execute(
            sb.table('users').update({'two_fa_verified': True}).eq('id', user['id']),
            'verify_user'
        )
        
        return json_response(True, 'Email verified', 200)
        
    except Exception:
        logger.exception('2FA verify error')
        return json_response(False, 'Server error', 500)


@app.route('/api/2fa/resend', methods=['POST'])
def api_2fa_resend():
    """
    Resend 2FA code (same as /api/2fa/send)
    
    Request Body:
        {
            "email": "user@gmail.com"
        }
    
    Response:
        {
            "success": true,
            "message": "Code sent"
        }
    """
    return api_2fa_send()

# ================================================================================
# SECTION 11: PROFILE ENDPOINTS
# ================================================================================
@app.route('/api/profile', methods=['GET'])
@token_required
def api_get_profile():
    """
    Get current user's profile
    
    Headers:
        Authorization: Bearer {token}
    
    Response:
        {
            "profile": {
                "firstName": "John",
                "lastName": "Doe",
                "middleName": "M",
                "suffix": "Jr",
                "email": "user@gmail.com",
                "status": "Active Student",
                "profilePicture": "url"
            },
            "academic": {
                "school": "ABC High School",
                "strand": "STEM",
                "gradeLevel": "12",
                "schoolYear": "2024-2025",
                "lrn": "123456789",
                "adviserSection": "12-A"
            },
            "personal": {
                "phone": "+639123456789",
                "dob": "2000-01-01",
                "address": "123 Main St",
                "emergency": "+639987654321"
            },
            "settings": {
                "emailNotifications": true,
                "twoFactor": false
            }
        }
    """
    try:
        user_id = request.user_data['user_id']
        user = fetch_one('users', id=user_id)
        
        if not user:
            return json_response(False, 'User not found', 404)
        
        return jsonify({
            'profile': {
                'firstName': user.get('first_name') or '',
                'lastName': user.get('last_name') or '',
                'middleName': user.get('middle_name') or '',
                'suffix': user.get('suffix') or '',
                'email': user.get('email') or '',
                'status': user.get('status') or 'Active Student',
                'profilePicture': user.get('profile_picture')
            },
            'academic': {
                'school': user.get('school') or '',
                'strand': user.get('strand') or '',
                'gradeLevel': user.get('grade_level') or '',
                'schoolYear': user.get('school_year') or '',
                'lrn': user.get('lrn') or '',
                'adviserSection': user.get('adviser_section') or ''
            },
            'personal': {
                'phone': user.get('phone') or '',
                'dob': user.get('date_of_birth') or '',
                'address': user.get('address') or '',
                'emergency': user.get('emergency_contact') or ''
            },
            'settings': {
                'emailNotifications': bool(user.get('email_notifications', True)),
                'twoFactor': bool(user.get('two_factor_enabled', False))
            }
        }), 200
        
    except Exception:
        logger.exception('Get profile error')
        return json_response(False, 'Server error', 500)


@app.route('/api/profile', methods=['PATCH'])
@token_required
def api_update_profile():
    """
    Update user profile
    
    Headers:
        Authorization: Bearer {token}
    
    Request Body:
        {
            "section": "profile" | "academic" | "personal" | "settings",
            "fields": {
                // Fields to update based on section
            }
        }
    
    Example - Update profile:
        {
            "section": "profile",
            "fields": {
                "firstName": "John",
                "lastName": "Doe"
            }
        }
    
    Response:
        {
            "success": true,
            "message": "Profile updated"
        }
    """
    try:
        user_id = request.user_data['user_id']
        data = request.get_json() or {}
        section = data.get('section')
        fields = data.get('fields', {})
        
        if not section or not fields:
            return json_response(False, 'Section and fields required', 400)
        
        sb = get_supabase()
        update_data = {}
        
        # Map fields by section
        if section == 'profile':
            field_map = {
                'firstName': 'first_name',
                'lastName': 'last_name',
                'middleName': 'middle_name',
                'suffix': 'suffix',
                'status': 'status'
            }
            for key, db_col in field_map.items():
                if key in fields:
                    update_data[db_col] = fields[key]
            
            # Update display name
            if any(k in fields for k in ['firstName', 'lastName', 'middleName', 'suffix']):
                user = fetch_one('users', id=user_id)
                first = fields.get('firstName', user.get('first_name', ''))
                middle = fields.get('middleName', user.get('middle_name', ''))
                last = fields.get('lastName', user.get('last_name', ''))
                suffix = fields.get('suffix', user.get('suffix', ''))
                
                display_name = first
                if middle:
                    display_name += f" {middle}"
                display_name += f" {last}"
                if suffix:
                    display_name += f", {suffix}"
                update_data['display_name'] = display_name.strip()
        
        elif section == 'academic':
            field_map = {
                'school': 'school',
                'strand': 'strand',
                'gradeLevel': 'grade_level',
                'schoolYear': 'school_year',
                'lrn': 'lrn',
                'adviserSection': 'adviser_section'
            }
            for key, db_col in field_map.items():
                if key in fields:
                    update_data[db_col] = fields[key]
        
        elif section == 'personal':
            field_map = {
                'phone': 'phone',
                'dob': 'date_of_birth',
                'address': 'address',
                'emergency': 'emergency_contact'
            }
            for key, db_col in field_map.items():
                if key in fields:
                    update_data[db_col] = fields[key]
        
        elif section == 'settings':
            if 'emailNotifications' in fields:
                update_data['email_notifications'] = bool(fields['emailNotifications'])
            if 'twoFactor' in fields:
                update_data['two_factor_enabled'] = bool(fields['twoFactor'])
        
        if not update_data:
            return json_response(False, 'No valid fields', 400)
        
        success, _, error = safe_execute(
            sb.table('users').update(update_data).eq('id', user_id),
            'update_profile'
        )
        
        if not success:
            return json_response(False, f'Failed: {error}', 500)
        
        return json_response(True, 'Profile updated', 200)
        
    except Exception:
        logger.exception('Update profile error')
        return json_response(False, 'Server error', 500)


@app.route('/api/profile/picture', methods=['POST'])
@token_required
def api_upload_profile_picture():
    """
    Upload profile picture
    
    Headers:
        Authorization: Bearer {token}
        Content-Type: multipart/form-data
    
    Form Data:
        profile_picture: File (image)
    
    Response:
        {
            "success": true,
            "message": "Profile picture updated",
            "picture_url": "https://..."
        }
    """
    try:
        user_id = request.user_data['user_id']
        
        if 'profile_picture' not in request.files:
            return json_response(False, 'No file uploaded', 400)
        
        file = request.files['profile_picture']
        
        if not file or file.filename == '':
            return json_response(False, 'No file selected', 400)
        
        # Process image
        image = Image.open(file)
        
        # Convert to RGB
        if image.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', image.size, (255, 255, 255))
            if image.mode == 'P':
                image = image.convert('RGBA')
            if image.mode == 'RGBA':
                background.paste(image, mask=image.split()[-1])
            image = background
        
        # Resize to 800x800
        image.thumbnail((800, 800), Image.Resampling.LANCZOS)
        
        # Save to bytes
        output = io.BytesIO()
        image.save(output, format='JPEG', quality=85)
        output.seek(0)
        
        # Upload to Supabase
        unique_filename = f"profile_{user_id}_{uuid.uuid4().hex}.jpg"
        sb = get_supabase()
        
        # Get old picture
        user = fetch_one('users', id=user_id)
        old_picture = user.get('profile_picture') if user else None
        
        # Upload new
        sb.storage.from_(SUPABASE_PROFILE_BUCKET).upload(
            unique_filename, 
            output.read(),
            file_options={"content-type": "image/jpeg"}
        )
        
        # Get URL
        picture_url = sb.storage.from_(SUPABASE_PROFILE_BUCKET).get_public_url(unique_filename)
        
        # Update user
        success, _, error = safe_execute(
            sb.table('users').update({'profile_picture': picture_url}).eq('id', user_id),
            'update_profile_picture'
        )
        
        if not success:
            sb.storage.from_(SUPABASE_PROFILE_BUCKET).remove([unique_filename])
            return json_response(False, 'Failed to update profile', 500)
        
        # Delete old
        if old_picture:
            try:
                old_filename = old_picture.split('/')[-1]
                sb.storage.from_(SUPABASE_PROFILE_BUCKET).remove([old_filename])
            except Exception:
                pass
        
        return json_response(True, 'Profile picture updated', 200, picture_url=picture_url)
        
    except Exception:
        logger.exception('Upload profile picture error')
        return json_response(False, 'Server error', 500)


# ================================================================================
# SECTION 12: TASKS API
# ================================================================================

@app.route('/api/tasks', methods=['GET', 'POST'])
@token_required
def api_tasks():
    """
    GET - List all tasks with filters
    POST - Create new task
    
    GET Query Parameters:
        - search: Search in title/notes
        - filter: all | pending | completed | high
        - sort: due | priority | created
    
    POST Request Body:
        {
            "title": "Complete assignment",
            "due": "2025-12-15",
            "priority": "high" | "medium" | "low",
            "notes": "Description",
            "type": "assignment" | "project" | "exam",
            "progress": 0-100
        }
    """
    sb = get_supabase()
    
    if request.method == 'GET':
        try:
            search = request.args.get('search', '').strip()
            filter_by = request.args.get('filter', 'all').strip()
            sort_by = request.args.get('sort', 'due').strip()
            
            query = sb.table('tasks').select('*')
            success, data, _ = safe_execute(query, 'get_tasks')
            
            if not success:
                return jsonify([])
            
            tasks = data or []
            
            # Apply filters
            if search:
                tasks = [t for t in tasks if search.lower() in (t.get('title', '') + t.get('notes', '')).lower()]
            
            if filter_by == 'pending':
                tasks = [t for t in tasks if not t.get('completed')]
            elif filter_by == 'completed':
                tasks = [t for t in tasks if t.get('completed')]
            elif filter_by == 'high':
                tasks = [t for t in tasks if t.get('priority') == 'high']
            
            # Sort
            if sort_by == 'due':
                tasks.sort(key=lambda x: (x.get('due') is None, x.get('due') or ''))
            elif sort_by == 'priority':
                priority_order = {'high': 0, 'medium': 1, 'low': 2}
                tasks.sort(key=lambda x: priority_order.get(x.get('priority', 'medium'), 1))
            else:
                tasks.sort(key=lambda x: x.get('created_at', ''), reverse=True)
            
            # Serialize
            serialized = [{
                'id': str(t.get('id')),
                'title': t.get('title'),
                'due': t.get('due'),
                'priority': t.get('priority', 'medium'),
                'notes': t.get('notes', ''),
                'status': t.get('status', 'pending'),
                'progress': int(t.get('progress', 0)),
                'type': t.get('type', 'assignment'),
                'completed': bool(t.get('completed')),
                'created_at': t.get('created_at')
            } for t in tasks]
            
            return jsonify(serialized)
        except Exception:
            logger.exception('Get tasks error')
            return jsonify([])
    
    # POST - Create task
    data = request.get_json() or {}
    title = data.get('title', '').strip()
    
    if not title:
        return json_response(False, 'Title required', 400)
    
    try:
        payload = {
            'title': title,
            'due': data.get('due') or data.get('dueDate'),
            'priority': data.get('priority', 'medium'),
            'notes': data.get('notes') or data.get('desc') or '',
            'status': 'pending',
            'progress': int(data.get('progress', 0)),
            'type': data.get('type', 'assignment'),
            'completed': bool(data.get('completed', False)),
        }
        
        success, created, error = safe_execute(
            sb.table('tasks').insert(payload),
            'create_task'
        )
        
        if not success or not created:
            return json_response(False, f'Failed: {error}', 500)
        
        task = created[0]
        task['id'] = str(task['id'])
        
        return json_response(True, 'Task created', 201, task=task)
    except Exception:
        logger.exception('Create task error')
        return json_response(False, 'Server error', 500)


@app.route('/api/tasks/<task_id>', methods=['GET', 'PATCH', 'DELETE'])
@token_required
def api_task_item(task_id):
    """
    GET - Get single task
    PATCH - Update task
    DELETE - Delete task
    
    PATCH Request Body:
        {
            "title": "New title",
            "priority": "high",
            "completed": true,
            // Any task fields
        }
    """
    sb = get_supabase()
    
    if request.method == 'GET':
        task = fetch_one('tasks', id=task_id)
        if not task:
            return json_response(False, 'Not found', 404)
        task['id'] = str(task['id'])
        return jsonify(task)
    
    if request.method == 'DELETE':
        try:
            success, _, _ = safe_execute(
                sb.table('tasks').delete().eq('id', task_id),
                'delete_task'
            )
            if not success:
                return json_response(False, 'Failed to delete', 500)
            return json_response(True, 'Task deleted')
        except Exception:
            logger.exception('Delete task error')
            return json_response(False, 'Server error', 500)
    
    # PATCH - Update
    data = request.get_json() or {}
    allowed = {}
    
    for key in ['title', 'notes', 'priority', 'status', 'due', 'progress', 'type', 'completed']:
        if key in data:
            allowed[key] = data[key]
    
    if not allowed:
        return json_response(False, 'No fields to update', 400)
    
    try:
        success, _, error = safe_execute(
            sb.table('tasks').update(allowed).eq('id', task_id),
            'update_task'
        )
        if not success:
            return json_response(False, f'Failed: {error}', 500)
        return json_response(True, 'Task updated')
    except Exception:
        logger.exception('Update task error')
        return json_response(False, 'Server error', 500)


# ================================================================================
# SECTION 13: MEETINGS API
# ================================================================================

@app.route('/api/meetings', methods=['GET', 'POST'])
@token_required
def api_meetings():
    """
    GET - List all meetings
    POST - Create new meeting
    
    POST Request Body:
        {
            "title": "Team Meeting",
            "type": "Team" | "One-on-One" | "All-Hands",
            "purpose": "Discussion",
            "datetime": "2025-12-15T10:00:00",
            "location": "Room 101",
            "meetLink": "https://meet.google.com/...",
            "attendees": ["user1@gmail.com", "user2@gmail.com"]
        }
    """
    sb = get_supabase()
    
    if request.method == 'GET':
        try:
            success, data, _ = safe_execute(
                sb.table('meetings').select('*').order('datetime'),
                'get_meetings'
            )
            if not success:
                return jsonify([])
            
            meetings = []
            for m in (data or []):
                attendees = []
                attendees_str = m.get('attendees')
                if attendees_str:
                    try:
                        if isinstance(attendees_str, str):
                            attendees = json.loads(attendees_str)
                        elif isinstance(attendees_str, list):
                            attendees = attendees_str
                    except Exception:
                        pass
                
                meetings.append({
                    'id': m.get('id'),
                    'title': m.get('title'),
                    'type': m.get('type'),
                    'purpose': m.get('purpose', ''),
                    'datetime': m.get('datetime'),
                    'location': m.get('location', ''),
                    'meetLink': m.get('meet_link', ''),
                    'status': m.get('status', 'Not Started'),
                    'attendees': attendees
                })
            
            return jsonify(meetings)
        except Exception:
            logger.exception('Get meetings error')
            return jsonify([])
    
    # POST
    data = request.get_json() or {}
    title = data.get('title', '').strip()
    datetime_str = data.get('datetime')
    
    if not title or not datetime_str:
        return json_response(False, 'Title and datetime required', 400)
    
    try:
        payload = {
            'title': title,
            'type': data.get('type', ''),
            'purpose': data.get('purpose', ''),
            'datetime': datetime_str,
            'location': data.get('location', ''),
            'meet_link': data.get('meetLink', ''),
            'status': 'Not Started',
            'attendees': json.dumps(data.get('attendees', [])),
        }
        
        success, created, error = safe_execute(
            sb.table('meetings').insert(payload),
            'create_meeting'
        )
        
        if not success or not created:
            return json_response(False, f'Failed: {error}', 500)
        
        return json_response(True, 'Meeting created', 201, meeting=created[0])
    except Exception:
        logger.exception('Create meeting error')
        return json_response(False, 'Server error', 500)


@app.route('/api/meetings/<int:meeting_id>', methods=['GET', 'PATCH', 'DELETE'])
@token_required
def api_meeting_item(meeting_id):
    """
    GET - Get single meeting
    PATCH - Update meeting
    DELETE - Delete meeting
    """
    sb = get_supabase()
    
    if request.method == 'GET':
        meeting = fetch_one('meetings', id=meeting_id)
        if not meeting:
            return json_response(False, 'Not found', 404)
        return jsonify(meeting)
    
    if request.method == 'DELETE':
        try:
            success, _, _ = safe_execute(
                sb.table('meetings').delete().eq('id', meeting_id),
                'delete_meeting'
            )
            if not success:
                return json_response(False, 'Failed to delete', 500)
            return json_response(True, 'Meeting deleted')
        except Exception:
            return json_response(False, 'Server error', 500)
    
    # PATCH
    data = request.get_json() or {}
    allowed = {}
    
    for key in ['title', 'type', 'purpose', 'datetime', 'location', 'status']:
        if key in data:
            allowed[key] = data[key]
    
    if 'meetLink' in data:
        allowed['meet_link'] = data['meetLink']
    if 'attendees' in data:
        allowed['attendees'] = json.dumps(data['attendees'])
    
    if not allowed:
        return json_response(False, 'No fields to update', 400)
    
    try:
        success, _, _ = safe_execute(
            sb.table('meetings').update(allowed).eq('id', meeting_id),
            'update_meeting'
        )
        if not success:
            return json_response(False, 'Failed to update', 500)
        return json_response(True, 'Meeting updated')
    except Exception:
        return json_response(False, 'Server error', 500)


# ================================================================================
# SECTION 14: BUDGET API
# ================================================================================

@app.route('/api/budget', methods=['GET'])
@token_required
def api_budget_root():
    """
    Get all budget data (categories, transactions, funds, tickets)
    
    Response:
        {
            "categories": [...],
            "transactions": [...],
            "funds": [],
            "tickets": []
        }
    """
    try:
        sb = get_supabase()
        
        # Categories
        success, cats, _ = safe_execute(
            sb.table('budget_categories').select('*').order('name'),
            'get_categories'
        )
        categories = [{
            'id': c['id'],
            'name': c['name'],
            'budget': float(c.get('budget', 0))
        } for c in (cats or [])]
        
        # Transactions
        success, txs, _ = safe_execute(
            sb.table('budget_transactions').select('*').order('date', desc=True),
            'get_transactions'
        )
        transactions = [{
            'id': t['id'],
            'type': t.get('type'),
            'category': t.get('category'),
            'description': t.get('description'),
            'amount': float(t.get('amount', 0)),
            'date': t.get('date'),
            'receipt': t.get('receipt'),
            'receipt_url': get_receipt_url(t.get('receipt')) if t.get('receipt') else None
        } for t in (txs or [])]
        
        return jsonify({
            'categories': categories,
            'transactions': transactions,
            'funds': [],
            'tickets': []
        })
    except Exception:
        logger.exception('Budget API error')
        return jsonify({'categories': [], 'transactions': [], 'funds': [], 'tickets': []})


@app.route('/api/budget/transactions', methods=['POST'])
@token_required
def api_create_transaction():
    """
    Create budget transaction with optional receipt
    
    Content-Type: multipart/form-data
    
    Form Data:
        - type: "expense" | "income"
        - category: Category name
        - description: Transaction description
        - amount: Amount (float)
        - date: Date (YYYY-MM-DD)
        - receipt: File (optional)
    """
    try:
        user_id = request.user_data['user_id']
        data = request.form.to_dict() if request.content_type and 'multipart' in request.content_type else request.get_json() or {}
        
        category = data.get('category', '').strip()
        if not category:
            return json_response(False, 'Category required', 400)
        
        # Verify category exists
        sb = get_supabase()
        cat = fetch_one('budget_categories', name=category)
        if not cat:
            return json_response(False, f'Category "{category}" does not exist', 400)
        
        # Handle receipt
        receipt_filename = None
        if 'receipt' in request.files:
            file = request.files['receipt']
            receipt_filename = save_uploaded_file(file, SUPABASE_RECEIPT_BUCKET)
        
        payload = {
            'type': data.get('type', 'expense'),
            'category': category,
            'description': data.get('description', ''),
            'amount': float(data.get('amount', 0)),
            'date': data.get('date'),
            'receipt': receipt_filename,
            'added_by': user_id
        }
        
        success, _, error = safe_execute(
            sb.table('budget_transactions').insert(payload),
            'create_transaction'
        )
        
        if not success:
            if receipt_filename:
                try:
                    sb.storage.from_(SUPABASE_RECEIPT_BUCKET).remove([receipt_filename])
                except Exception:
                    pass
            return json_response(False, f'Failed: {error}', 500)
        
        return json_response(True, 'Transaction created', 201)
    except Exception:
        logger.exception('Create transaction error')
        return json_response(False, 'Server error', 500)
# ================================================================================
# SECTION 14.5: STUDENTS API
# ================================================================================

@app.route('/api/students', methods=['GET'])
@token_required
def api_students():
    """
    Get all students (users with role='user')
    
    Response:
        [
            {
                "id": 1,
                "name": "John Doe",
                "email": "john@gmail.com",
                "school": "ABC High School",
                "strand": "STEM",
                "gradeLevel": "12"
            },
            ...
        ]
    """
    try:
        sb = get_supabase()
        
        # Get all users with role='user'
        query = sb.table('users').select('*').eq('role', 'user').order('display_name')
        success, data, _ = safe_execute(query, 'get_students')
        
        if not success:
            return jsonify([])
        
        students = []
        for student in (data or []):
            students.append({
                'id': student.get('id'),
                'name': student.get('display_name') or f"{student.get('first_name', '')} {student.get('last_name', '')}".strip(),
                'email': student.get('email'),
                'school': student.get('school', ''),
                'strand': student.get('strand', ''),
                'gradeLevel': student.get('grade_level', ''),
                'lrn': student.get('lrn', ''),
                'status': student.get('status', 'Active Student')
            })
        
        logger.info(f'✅ Fetched {len(students)} students')
        return jsonify(students)
        
    except Exception:
        logger.exception('Get students error')
        return jsonify([])
    
# ================================================================================
# SECTION 15: ERROR HANDLERS
# ================================================================================

@app.errorhandler(404)
def not_found(e):
    """Handle 404 errors"""
    return json_response(False, 'Endpoint not found', 404)


@app.errorhandler(500)
def internal_error(e):
    """Handle 500 errors"""
    logger.exception('Internal server error')
    return json_response(False, 'Internal server error', 500)


@app.errorhandler(413)
def file_too_large(e):
    """Handle file size errors"""
    return json_response(False, 'File too large', 413)


# ================================================================================
# SECTION 16: HEALTH CHECK & DEBUG
# ================================================================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    })


@app.route('/api/config', methods=['GET'])
def api_config():
    """Get API configuration status"""
    return jsonify({
        'supabase_configured': bool(SUPABASE_URL and SUPABASE_KEY),
        'supabase_available': SUPABASE_AVAILABLE,
        'smtp_configured': bool(SMTP_EMAIL and SMTP_PASS),
        'version': '3.0'
    })


# ================================================================================
# SECTION 17: APPLICATION STARTUP
# ================================================================================

if __name__ == '__main__':
    logger.info('=' * 80)
    logger.info('LIKHAYAG MOBILE API - Starting...')
    logger.info('=' * 80)
    
    # Validate configuration
    if not SUPABASE_URL or not SUPABASE_KEY:
        logger.error('❌ SUPABASE_URL and SUPABASE_KEY must be set in environment')
        exit(1)
    
    if not SUPABASE_AVAILABLE:
        logger.error('❌ Supabase library not installed. Run: pip install supabase')
        exit(1)
    
    # Test database connection
    try:
        sb = get_supabase()
        success, _, _ = safe_execute(sb.table('users').select('id').limit(1), 'startup_test')
        if success:
            logger.info('✅ Supabase connection successful')
        else:
            logger.warning('⚠️  Supabase connection test failed - check credentials')
    except Exception as e:
        logger.error(f'❌ Startup check failed: {e}')
        exit(1)
    
    # Start server
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() in ('true', '1')
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', '5000'))
    
    logger.info(f'🚀 Starting server on {host}:{port}')
    logger.info(f'📱 Debug mode: {debug_mode}')
    logger.info('=' * 80)
    
    app.run(debug=debug_mode, host=host, port=port)

