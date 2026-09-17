// Optional Vercel serverless endpoint. Install `stripe` before enabling this route.
// npm i stripe
export default async function handler(req,res){
 if(req.method!=='POST') return res.status(405).json({error:'Method not allowed'});
 if(!process.env.STRIPE_SECRET_KEY) return res.status(501).json({error:'Set STRIPE_SECRET_KEY in Vercel before using checkout.'});
 const Stripe=(await import('stripe')).default; const stripe=new Stripe(process.env.STRIPE_SECRET_KEY);
 const {priceId,email}=req.body||{}; if(!priceId)return res.status(400).json({error:'priceId required'});
 const session=await stripe.checkout.sessions.create({mode:'subscription',line_items:[{price:priceId,quantity:1}],customer_email:email,success_url:`${req.headers.origin}/dashboard?checkout=success`,cancel_url:`${req.headers.origin}/dashboard?checkout=cancelled`});
 res.status(200).json({url:session.url});
}
