// api/verify-payment.js
// Vercel serverless function — verifies Razorpay signature and upgrades user plan in Supabase

const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

const hasSupabaseAdmin = !!(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY);
const supabase = hasSupabaseAdmin
  ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  : null;

module.exports = async (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, plan, user_id, report_data } = req.body;

    // Verify Razorpay signature
    const body = razorpay_order_id + '|' + razorpay_payment_id;
    const expected = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(body)
      .digest('hex');

    if (expected !== razorpay_signature) {
      return res.status(400).json({ error: 'Invalid payment signature' });
    }

    if (user_id) {
      if (!supabase) return res.status(500).json({ error: 'Supabase admin is not configured' });

      const { error } = await supabase
        .from('reports')
        .upsert({
          user_id,
          plan,
          payment_id: razorpay_payment_id,
          order_id: razorpay_order_id,
          paid_at: new Date().toISOString(),
          report_data: report_data,
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id' });

      if (error) {
        console.error('Supabase error:', error);
        return res.status(500).json({ error: 'Failed to save report' });
      }
    }

    return res.status(200).json({ success: true, plan, payment_id: razorpay_payment_id, saved: !!user_id });
  } catch (err) {
    console.error('Server error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};
