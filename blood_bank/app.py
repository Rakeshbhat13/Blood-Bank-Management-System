from flask import Flask, render_template, request, redirect, url_for, flash
import mysql.connector
from datetime import date, timedelta

app = Flask(__name__)
app.secret_key = 'bloodbank_secret_key'

# ── Database connection ───────────────────────────────────────

from dotenv import load_dotenv
import os

load_dotenv()

def get_db():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME')
    )
# ── HOME / DASHBOARD ─────────────────────────────────────────

@app.route('/')
def dashboard():
    db = get_db()
    cur = db.cursor(dictionary=True)

    cur.execute("SELECT COUNT(*) AS total FROM donors")
    total_donors = cur.fetchone()['total']

    cur.execute("SELECT SUM(units_available) AS total FROM blood_inventory")
    total_units = cur.fetchone()['total'] or 0

    cur.execute("SELECT COUNT(*) AS total FROM blood_requests WHERE status='Pending'")
    pending_requests = cur.fetchone()['total']

    cur.execute("""
        SELECT COUNT(*) AS total FROM blood_units
        WHERE status='Available'
        AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
    """)
    expiring_soon = cur.fetchone()['total']

    cur.execute("SELECT blood_group, units_available FROM blood_inventory ORDER BY blood_group")
    inventory = cur.fetchall()

    cur.execute("""
        SELECT unit_id, blood_group,
               DATEDIFF(expiry_date, CURDATE()) AS days_left
        FROM blood_units
        WHERE status='Available'
          AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        ORDER BY expiry_date ASC
    """)
    expiry_alerts = cur.fetchall()

    cur.execute("""
        SELECT patient_name, blood_group, hospital_name, status
        FROM blood_requests
        WHERE status='Pending'
        ORDER BY request_date DESC
        LIMIT 5
    """)
    recent_requests = cur.fetchall()

    db.close()
    return render_template(
        'index.html',
        total_donors=total_donors,
        total_units=total_units,
        pending_requests=pending_requests,
        expiring_soon=expiring_soon,
        inventory=inventory,
        expiry_alerts=expiry_alerts,
        recent_requests=recent_requests
    )

# ── DONORS ───────────────────────────────────────────────────

@app.route('/donors')
def donors():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM donors ORDER BY name")
    all_donors = cur.fetchall()
    db.close()
    return render_template(
        'donors.html',
        donors=all_donors,
        current_date=date.today(),
        expiry_date=date.today() + timedelta(days=90)
    )

@app.route('/donors/add', methods=['POST'])
def add_donor():
    db = get_db()
    cur = db.cursor(dictionary=True)
    try:
        cur.execute("""
            INSERT INTO donors (name, age, gender, blood_group, phone, email, address)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            request.form['name'],
            request.form['age'],
            request.form['gender'],
            request.form['blood_group'],
            request.form['phone'],
            request.form.get('email', ''),
            request.form.get('address', '')
        ))
        donor_id = cur.lastrowid

        donation_date = date.today()
        expiry_date = date.today() + timedelta(days=90)
        blood_group = request.form['blood_group']

        cur.execute("""
            INSERT INTO blood_units (blood_group, donor_id, collection_date, expiry_date, status)
            VALUES (%s, %s, %s, %s, 'Available')
        """, (blood_group, donor_id, donation_date, expiry_date))
        unit_id = cur.lastrowid

        cur.execute("""
            INSERT INTO donations (donor_id, unit_id, donation_date, quantity)
            VALUES (%s, %s, %s, %s)
        """, (donor_id, unit_id, donation_date, 1))

        cur.execute("""
            UPDATE donors SET last_donation_date=%s WHERE donor_id=%s
        """, (donation_date, donor_id))

        db.commit()
        flash('Donor registered successfully.', 'success')
    except Exception as e:
        db.rollback()
        flash(f'Error: {str(e)}', 'danger')
    finally:
        db.close()
    return redirect(url_for('donors'))

@app.route('/donors/donate', methods=['POST'])
def add_donation():
    db = get_db()
    cur = db.cursor(dictionary=True)
    try:
        donor_id = request.form['donor_id']
        donation_date_str = request.form.get('donation_date', '')
        expiry_date_str = request.form.get('expiry_date', '')
        quantity = int(request.form.get('quantity', '1') or '1')

        if quantity <= 0:
            raise ValueError('Donation quantity must be at least 1.')

        donation_date = date.fromisoformat(donation_date_str) if donation_date_str else date.today()
        expiry_date = date.fromisoformat(expiry_date_str) if expiry_date_str else (date.today() + timedelta(days=90))

        if expiry_date <= donation_date:
            raise ValueError('Expiry date must be after the donation date.')
        if donation_date > date.today():
            raise ValueError('Donation date cannot be in the future.')

        cur.execute("SELECT blood_group FROM donors WHERE donor_id=%s", (donor_id,))
        donor = cur.fetchone()
        if not donor:
            raise ValueError('Donor not found.')

        blood_group = donor['blood_group']
        cur2 = db.cursor()
        first_unit_id = None

        for _ in range(quantity):
            cur2.execute("""
                INSERT INTO blood_units (blood_group, donor_id, collection_date, expiry_date, status)
                VALUES (%s, %s, %s, %s, 'Available')
            """, (blood_group, donor_id, donation_date, expiry_date))
            if first_unit_id is None:
                first_unit_id = cur2.lastrowid

        cur2.execute("""
            INSERT INTO donations (donor_id, unit_id, donation_date, quantity)
            VALUES (%s, %s, %s, %s)
        """, (donor_id, first_unit_id, donation_date, quantity))

        cur2.execute("""
            UPDATE donors SET last_donation_date=%s WHERE donor_id=%s
        """, (donation_date, donor_id))

        db.commit()
        flash('Donation recorded successfully!', 'success')
    except Exception as e:
        db.rollback()
        flash(f'Error: {str(e)}', 'danger')
    finally:
        db.close()
    return redirect(url_for('donors'))

# ── INVENTORY ────────────────────────────────────────────────

@app.route('/inventory')
def inventory():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM blood_inventory ORDER BY blood_group")
    inventory_data = cur.fetchall()

    cur.execute("""
        SELECT bu.unit_id, bu.blood_group, d.name AS donor_name,
               bu.collection_date, bu.expiry_date, bu.status
        FROM blood_units bu
        JOIN donors d ON bu.donor_id = d.donor_id
        ORDER BY bu.collection_date DESC
    """)
    units = cur.fetchall()

    db.close()
    return render_template('inventory.html', inventory=inventory_data, units=units)

# ── REPORTS ──────────────────────────────────────────────────

@app.route('/reports')
def reports():
    db = get_db()
    cur = db.cursor(dictionary=True)

    cur.execute("""
        SELECT bi.blood_group, bi.units_available,
               COALESCE(p.pending_requests, 0) AS pending_requests
        FROM blood_inventory bi
        LEFT JOIN (
            SELECT blood_group, COUNT(*) AS pending_requests
            FROM blood_requests
            WHERE status='Pending'
            GROUP BY blood_group
        ) p ON bi.blood_group = p.blood_group
        ORDER BY bi.blood_group
    """)
    summary = cur.fetchall()

    cur.execute("""
        SELECT unit_id, blood_group, expiry_date,
               DATEDIFF(expiry_date, CURDATE()) AS days_left
        FROM blood_units
        WHERE status='Available'
          AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
        ORDER BY expiry_date ASC
    """)
    expiring = cur.fetchall()

    cur.execute("""
        SELECT d.name, bu.blood_group, donations.donation_date,
               donations.unit_id, bu.expiry_date, bu.status
        FROM donations
        JOIN donors d ON donations.donor_id = d.donor_id
        JOIN blood_units bu ON donations.unit_id = bu.unit_id
        ORDER BY donations.donation_date DESC
    """)
    donor_history = cur.fetchall()

    db.close()
    return render_template(
        'reports.html',
        summary=summary,
        expiring=expiring,
        donor_history=donor_history
    )

# ── REQUESTS ─────────────────────────────────────────────────

@app.route('/requests')
def requests_page():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM blood_requests ORDER BY request_date DESC")
    all_requests = cur.fetchall()
    db.close()
    return render_template('requests.html', requests=all_requests)

@app.route('/requests/add', methods=['POST'])
def add_request():
    db = get_db()
    cur = db.cursor()
    try:
        patient_name = request.form['patient_name'].strip()
        blood_group = request.form['blood_group']
        hospital_name = request.form['hospital_name'].strip()
        units_needed = int(request.form['units_needed'])

        if units_needed <= 0:
            raise ValueError('Units needed must be at least 1.')

        cur.execute(
            "SELECT COUNT(*) FROM blood_requests "
            "WHERE patient_name=%s AND blood_group=%s "
            "AND hospital_name=%s AND status='Pending'",
            (patient_name, blood_group, hospital_name)
        )
        if cur.fetchone()[0] > 0:
            raise ValueError('A pending request for this patient, blood group and hospital already exists.')

        cur.execute("""
            INSERT INTO blood_requests
            (patient_name, blood_group, units_needed, hospital_name, request_date, status)
            VALUES (%s, %s, %s, %s, %s, 'Pending')
        """, (
            patient_name,
            blood_group,
            units_needed,
            hospital_name,
            date.today()
        ))
        db.commit()
        flash('Request submitted successfully!', 'success')
    except ValueError as e:
        flash(str(e), 'danger')
    except Exception as e:
        flash(f'Error: {str(e)}', 'danger')
    finally:
        db.close()
    return redirect(url_for('requests_page'))

@app.route('/requests/fulfill/<int:request_id>', methods=['POST'])
def fulfill_request(request_id):
    db = get_db()
    cur = db.cursor(dictionary=True)
    try:
        cur.execute("SELECT blood_group, units_needed, status FROM blood_requests WHERE request_id=%s", (request_id,))
        request_row = cur.fetchone()
        if not request_row:
            raise ValueError('Request not found.')

        if request_row['status'] != 'Pending':
            flash('Request is already fulfilled or closed.', 'info')
            return redirect(url_for('requests_page'))

        blood_group = request_row['blood_group']
        units_needed = request_row['units_needed']

        cur.execute("SELECT units_available FROM blood_inventory WHERE blood_group=%s", (blood_group,))
        stock = cur.fetchone()

        if not stock:
            flash('No inventory record found for this blood group.', 'danger')
        elif stock['units_available'] < units_needed:
            flash(f'Not enough units available: needed {units_needed}, available {stock['units_available']}.', 'danger')
        else:
            cur.execute(
                "SELECT COUNT(*) AS available_units FROM blood_units "
                "WHERE blood_group=%s AND status='Available'",
                (blood_group,)
            )
            available = cur.fetchone()['available_units']

            if available < units_needed:
                flash(f'Not enough available units in inventory: needed {units_needed}, available {available}.', 'danger')
            else:
                cur.execute("""
                    UPDATE blood_requests
                    SET status='Fulfilled'
                    WHERE request_id=%s
                """, (request_id,))
                if cur.rowcount != 1:
                    raise ValueError('Could not fulfill the request.')
                db.commit()
                flash('Request fulfilled successfully!', 'success')
    except Exception as e:
        db.rollback()
        flash(str(e), 'danger')
    finally:
        db.close()
    return redirect(url_for('requests_page'))

if __name__ == '__main__':
    app.run(debug=True)
