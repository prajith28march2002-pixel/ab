// server.js - Universal Node.js server
// Works on: Render, Railway, Fly.io, VPS, Heroku, DigitalOcean, etc.
// For Vercel: add vercel.json (see README) - uses same server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');
const Razorpay = require('razorpay');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Supabase admin client (service role - server only)
const hasSupabaseAdmin = !!(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY);
const supabase = hasSupabaseAdmin
  ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  : null;

// Razorpay
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

// ─── API: Public frontend config ──────────────────────────────────────────────
app.get('/api/public-config', (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.json({
    supabaseUrl: process.env.SUPABASE_URL || '',
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || ''
  });
});


// ─── API: Optional verified fee rows for ROI ─────────────────────────────────
app.get('/api/college-fees', async (req, res) => {
  try {
    if (!supabase) return res.json({ rows: [] });
    const { data, error } = await supabase
      .from('college_program_fees')
      .select('record_id, institution_name, programme_name, annual_fee, total_fee, source_url, source_note, updated_at')
      .order('institution_name', { ascending: true });
    if (error) {
      console.error('college-fees:', error.message);
      return res.status(500).json({ error: 'Could not load fee rows' });
    }
    res.json({ rows: data || [] });
  } catch (e) {
    console.error('college-fees:', e.message);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── API: Create Razorpay Order ───────────────────────────────────────────────
app.post('/api/create-order', async (req, res) => {
  try {
    const { plan } = req.body;
    const amounts = { basic: 1900, pro: 4900 }; // paise
    if (!amounts[plan]) return res.status(400).json({ error: 'Invalid plan' });
    const order = await razorpay.orders.create({
      amount: amounts[plan], currency: 'INR',
      receipt: `abkya_${plan}_${Date.now()}`,
      notes: { plan }
    });
    res.json({ order_id: order.id, amount: amounts[plan], currency: 'INR', key: process.env.RAZORPAY_KEY_ID });
  } catch (e) {
    console.error('create-order:', e.message);
    res.status(500).json({ error: 'Could not create order' });
  }
});

// ─── API: Verify Payment + Save Report ───────────────────────────────────────
app.post('/api/verify-payment', async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, plan, user_id, report_data } = req.body;
    const body = razorpay_order_id + '|' + razorpay_payment_id;
    const expected = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET).update(body).digest('hex');
    if (expected !== razorpay_signature) return res.status(400).json({ error: 'Invalid signature' });

    if (user_id) {
      if (!supabase) return res.status(500).json({ error: 'Supabase admin is not configured' });

      const { error } = await supabase.from('reports').upsert({
        user_id, plan,
        payment_id: razorpay_payment_id,
        order_id: razorpay_order_id,
        paid_at: new Date().toISOString(),
        report_data,
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' });

      if (error) { console.error('supabase:', error); return res.status(500).json({ error: 'DB error' }); }
    }

    res.json({ success: true, plan, saved: !!user_id });
  } catch (e) {
    console.error('verify-payment:', e.message);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── SPA fallback ────────────────────────────────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`abkya running on :${PORT}`));
