# 🩸 Blood Bank Management System

A web-based Blood Bank Management System built with **Python (Flask)** and **MySQL**. The system manages donor records, blood inventory, and transfusion requests across all 8 blood groups, with automated trigger-based workflows for real-time inventory tracking.

---

## 🚀 Features

- **Dashboard** — Live overview of total donors, available blood units, pending requests, and expiry alerts
- **Donor Management** — Register donors, record repeat donations, and track donation history
- **Blood Inventory** — Real-time inventory per blood group with unit-level tracking and expiry monitoring
- **Transfusion Requests** — Submit, view, and fulfill blood requests with stock validation
- **Reports** — Inventory summary, expiry alerts (within 30 days), and full donor history
- **Automated Triggers** — 4 MySQL triggers to enforce inventory consistency and log transactions automatically

---

## 🛠️ Tech Stack

| Layer      | Technology                        |
|------------|-----------------------------------|
| Backend    | Python 3, Flask                   |
| Database   | MySQL, mysql-connector-python     |
| Frontend   | HTML5, CSS3 (dark terminal theme) |
| Templating | Jinja2                            |

---

## 🗃️ Database Schema

The system uses a **5-table relational schema**:

| Table             | Description                                      |
|-------------------|--------------------------------------------------|
| `donors`          | Donor personal info and last donation date       |
| `blood_units`     | Individual blood unit records with expiry dates  |
| `donations`       | Records linking donors to their donated units    |
| `blood_inventory` | Aggregated available units per blood group       |
| `blood_requests`  | Transfusion requests with status tracking        |

**4 MySQL Triggers** automate:
- Inventory count update on new blood unit insertion
- Inventory decrement when a request is fulfilled
- Expiry-based status updates
- Transaction logging for audit trail

---

## ⚙️ Setup & Installation

### Prerequisites
- Python 3.10+
- MySQL Server
- pip

### 1. Clone the repository
```bash
git clone https://github.com/Rakeshbhat13/Blood-Bank-Management-System.git
cd Blood-Bank-Management-System
```

### 2. Install dependencies
```bash
pip install flask mysql-connector-python
```

### 3. Set up the database
Open MySQL and run the schema file:
```sql
CREATE DATABASE blood_bank_db;
USE blood_bank_db;
-- Run the schema.sql file here to create tables and triggers
```

### 4. Configure database credentials
Open `app.py` and update the `get_db()` function with your MySQL credentials:
```python
def get_db():
    return mysql.connector.connect(
        host='localhost',
        user='your_mysql_username',
        password='your_mysql_password',
        database='blood_bank_db'
    )
```

> ⚠️ **Security Note:** Avoid hardcoding credentials. Consider using environment variables or a `.env` file (see `.gitignore`).

### 5. Run the application
```bash
python app.py
```

Visit `http://127.0.0.1:5000` in your browser.

---

## 📁 Project Structure

```
blood_bank/
├── app.py                  # Flask application and all route handlers
├── static/
│   └── style.css           # Dark terminal-style UI stylesheet
└── templates/
    ├── base.html           # Base layout template
    ├── index.html          # Dashboard
    ├── donors.html         # Donor management page
    ├── inventory.html      # Blood inventory page
    ├── requests.html       # Transfusion requests page
    └── reports.html        # Reports and analytics page
```

---

## 👥 Team

| Name            | Role          |
|-----------------|---------------|
| B Rakesh Bhat   | Developer     |
| B G Bharadwaj   | Developer     |
| Jnanamshu K     | Developer     |

**Institution:** NMAM Institute of Technology, Nitte (Deemed to be University)
**Course:** CS2102-1 | Database Management Systems Mini Project

---

## 📄 License

This project is for academic purposes only.
