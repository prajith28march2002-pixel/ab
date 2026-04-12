// api/create-order.js
// Creates a Razorpay order server-side

const Razorpay = require('razorpay');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { plan } = req.body;
    const amounts = { basic: 1900, pro: 9900 }; // in paise
    const amount = amounts[plan];
    if (!amount) return res.status(400).json({ error: 'Invalid plan' });

    const order = await razorpay.orders.create({
      amount,
      currency: 'INR',
      receipt: `abkya_${plan}_${Date.now()}`,
      notes: { plan }
    });

    return res.status(200).json({ order_id: order.id, amount, currency: 'INR', key: process.env.RAZORPAY_KEY_ID });
  } catch (err) {
    console.error('Razorpay error:', err);
    return res.status(500).json({ error: 'Could not create order' });
  }
};
