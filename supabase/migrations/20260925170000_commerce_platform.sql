-- Phase 1: non-destructive commerce platform expansion.
-- Keeps the existing products, profiles, orders and order_items data.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- Dynamic categories
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text not null default '',
  image_url text,
  show_on_homepage boolean not null default true,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint categories_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

-- Extend products without removing existing columns/data.
alter table public.products add column if not exists slug text;
alter table public.products add column if not exists sku text;
alter table public.products add column if not exists category_id uuid references public.categories(id) on delete restrict;
alter table public.products add column if not exists brand text not null default '';
alter table public.products add column if not exists short_description_sq text not null default '';
alter table public.products add column if not exists short_description_en text not null default '';
alter table public.products add column if not exists discount_percentage numeric(5,2) not null default 0;
alter table public.products add column if not exists discount_amount numeric(12,2) not null default 0;
alter table public.products add column if not exists discount_start timestamptz;
alter table public.products add column if not exists discount_end timestamptz;
alter table public.products add column if not exists stock integer not null default 0;
alter table public.products add column if not exists warranty text not null default 'Pa garanci';
alter table public.products add column if not exists is_new boolean not null default false;
alter table public.products add column if not exists is_featured boolean not null default false;
alter table public.products add column if not exists show_on_homepage boolean not null default true;
alter table public.products add column if not exists sort_order integer not null default 0;
alter table public.products add column if not exists updated_at timestamptz not null default now();

update public.products
set slug = coalesce(nullif(slug,''), lower(regexp_replace(regexp_replace(name_en, '[^a-zA-Z0-9]+', '-', 'g'), '(^-|-$)', '', 'g')) || '-' || left(id::text,8)),
    sku = coalesce(nullif(sku,''), 'SKU-' || upper(left(id::text,8))),
    stock = case when stock = 0 then 100 else stock end
where slug is null or sku is null or stock = 0;

-- Commercial validation constraints (added safely when missing).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='products_discount_percentage_check') THEN
    ALTER TABLE public.products ADD CONSTRAINT products_discount_percentage_check CHECK (discount_percentage>=0 AND discount_percentage<=100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='products_discount_amount_check') THEN
    ALTER TABLE public.products ADD CONSTRAINT products_discount_amount_check CHECK (discount_amount>=0 AND discount_amount<=price);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='products_single_discount_type_check') THEN
    ALTER TABLE public.products ADD CONSTRAINT products_single_discount_type_check CHECK (NOT (discount_percentage>0 AND discount_amount>0));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='products_stock_check') THEN
    ALTER TABLE public.products ADD CONSTRAINT products_stock_check CHECK (stock>=0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='products_discount_dates_check') THEN
    ALTER TABLE public.products ADD CONSTRAINT products_discount_dates_check CHECK (discount_end IS NULL OR discount_start IS NULL OR discount_end>discount_start);
  END IF;
END $$;

insert into public.categories(name,slug,description,show_on_homepage,is_active,sort_order)
values('Atlete','atlete','Atlete dhe këpucë sportive',true,true,10)
on conflict(slug) do nothing;
update public.products set category_id=(select id from public.categories where slug='atlete')
where category_id is null and category='sneakers';

create unique index if not exists products_slug_unique on public.products(slug) where slug is not null;
create unique index if not exists products_sku_unique on public.products(sku) where sku is not null;
create index if not exists products_category_idx on public.products(category_id);
create index if not exists products_home_idx on public.products(show_on_homepage, active, sort_order);
create index if not exists products_featured_idx on public.products(is_featured, active, sort_order);
create index if not exists products_search_idx on public.products using gin (to_tsvector('simple', coalesce(name_sq,'') || ' ' || coalesce(name_en,'') || ' ' || coalesce(sku,'') || ' ' || coalesce(brand,'')));

-- Product media gallery
create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text not null,
  alt_text text not null default '',
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists product_images_product_idx on public.product_images(product_id, sort_order);
create unique index if not exists product_images_one_primary on public.product_images(product_id) where is_primary;

-- Homepage hero media
create table if not exists public.hero_slides (
  id uuid primary key default gen_random_uuid(),
  media_type text not null default 'image' check (media_type in ('image','video')),
  title text not null,
  subtitle text not null default '',
  description text not null default '',
  media_url text not null,
  button_text text not null default '',
  button_url text not null default '',
  start_date timestamptz,
  end_date timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hero_date_order check (end_date is null or start_date is null or end_date > start_date)
);

-- Sponsors and advertising campaigns
create table if not exists public.sponsors (
  id uuid primary key default gen_random_uuid(),
  company_name text not null,
  logo_url text not null,
  description text not null default '',
  website text,
  phone text,
  email text,
  address text,
  social_links jsonb not null default '{}'::jsonb,
  advertising_text text not null default '',
  advertising_url text,
  start_date timestamptz,
  end_date timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sponsor_date_order check (end_date is null or start_date is null or end_date > start_date)
);

create table if not exists public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  banner_url text not null,
  logo_url text,
  destination_url text,
  start_date timestamptz,
  end_date timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint campaign_date_order check (end_date is null or start_date is null or end_date > start_date)
);

-- Homepage CMS and editable site/footer configuration
create table if not exists public.homepage_sections (
  section_key text primary key,
  title text not null,
  is_visible boolean not null default true,
  sort_order integer not null default 0,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.homepage_sections(section_key,title,is_visible,sort_order) values
 ('hero','Slideshow',true,10),
 ('categories','Kategoritë',true,20),
 ('new_products','Produktet e Reja',true,30),
 ('featured_products','Produktet e Zgjedhura',true,40),
 ('offers','Ofertat',true,50),
 ('trust','Besimi dhe Dërgesa',true,60),
 ('sponsors','Partnerët & Sponsorët',true,70)
on conflict (section_key) do nothing;

create table if not exists public.site_settings (
  setting_key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.site_settings(setting_key,value) values
 ('store', '{"name":"Dyqani Online","currency":"EUR","delivery_hours":72}'::jsonb),
 ('contact', '{"phone":"","email":"","address":""}'::jsonb),
 ('social', '{"facebook":"","instagram":"","tiktok":""}'::jsonb),
 ('footer', '{"about":"","privacy_url":"","terms_url":"","returns_url":""}'::jsonb)
on conflict (setting_key) do nothing;

-- Expand order data while preserving existing orders.
alter table public.orders alter column customer_email drop not null;
alter table public.orders add column if not exists order_number text;
alter table public.orders add column if not exists first_name text;
alter table public.orders add column if not exists last_name text;
alter table public.orders add column if not exists phone text;
alter table public.orders add column if not exists country text;
alter table public.orders add column if not exists city text;
alter table public.orders add column if not exists address text;
alter table public.orders add column if not exists street text;
alter table public.orders add column if not exists apartment text;
alter table public.orders add column if not exists payment_method text not null default 'cash';
alter table public.orders add column if not exists subtotal numeric(12,2) not null default 0;
alter table public.orders add column if not exists discount numeric(12,2) not null default 0;
alter table public.orders add column if not exists expected_delivery_at timestamptz;
alter table public.orders add column if not exists idempotency_key text;
alter table public.orders add column if not exists updated_at timestamptz not null default now();

create sequence if not exists public.order_number_seq start 1;
update public.orders
set order_number = coalesce(order_number, 'ORD-' || to_char(created_at,'YYYYMMDD') || '-' || lpad(nextval('public.order_number_seq')::text,6,'0')),
    expected_delivery_at = coalesce(expected_delivery_at, created_at + interval '72 hours')
where order_number is null or expected_delivery_at is null;
create unique index if not exists orders_order_number_unique on public.orders(order_number) where order_number is not null;
create unique index if not exists orders_idempotency_unique on public.orders(idempotency_key) where idempotency_key is not null;
create index if not exists orders_status_date_idx on public.orders(status, created_at desc);
create index if not exists orders_customer_search_idx on public.orders(lower(customer_name), lower(customer_email), phone);

alter table public.order_items add column if not exists product_name_snapshot text;
alter table public.order_items add column if not exists sku_snapshot text;
alter table public.order_items add column if not exists image_url_snapshot text;
alter table public.order_items add column if not exists discount numeric(12,2) not null default 0;
alter table public.order_items add column if not exists line_total numeric(12,2);
update public.order_items oi
set product_name_snapshot = coalesce(oi.product_name_snapshot,p.name_sq),
    sku_snapshot = coalesce(oi.sku_snapshot,p.sku),
    image_url_snapshot = coalesce(oi.image_url_snapshot,'assets/' || p.image_key),
    line_total = coalesce(oi.line_total,(oi.unit_price * oi.quantity) - oi.discount)
from public.products p where p.id=oi.product_id;

-- Allow product deletion without destroying historical order snapshots.
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid='public.order_items'::regclass and contype='f'
      and pg_get_constraintdef(oid) like '%product_id%'
  loop
    execute format('alter table public.order_items drop constraint %I', c.conname);
  end loop;
end $$;
alter table public.order_items alter column product_id drop not null;
alter table public.order_items add constraint order_items_product_id_fkey foreign key(product_id) references public.products(id) on delete set null;

-- Expanded order lifecycle.
alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check check (status in ('new','confirmed','preparing','shipped','delivered','cancelled','completed'));

-- Updated-at triggers
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['categories','products','hero_slides','sponsors','ad_campaigns','homepage_sections','site_settings','orders']
  LOOP
    EXECUTE format('drop trigger if exists %I on public.%I','set_'||t||'_updated_at',t);
    EXECUTE format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()','set_'||t||'_updated_at',t);
  END LOOP;
END $$;

-- RLS
alter table public.categories enable row level security;
alter table public.product_images enable row level security;
alter table public.hero_slides enable row level security;
alter table public.sponsors enable row level security;
alter table public.ad_campaigns enable row level security;
alter table public.homepage_sections enable row level security;
alter table public.site_settings enable row level security;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['categories','product_images','hero_slides','sponsors','ad_campaigns','homepage_sections','site_settings']
  LOOP
    EXECUTE format('drop policy if exists %I on public.%I',t||'_public_read',t);
    EXECUTE format('drop policy if exists %I on public.%I',t||'_admin_all',t);
    EXECUTE format('create policy %I on public.%I for select using (true)',t||'_public_read',t);
    EXECUTE format('create policy %I on public.%I for all using (public.is_admin()) with check (public.is_admin())',t||'_admin_all',t);
  END LOOP;
END $$;

-- Restrict public reads to currently displayable content where needed.
drop policy if exists hero_slides_public_read on public.hero_slides;
create policy hero_slides_public_read on public.hero_slides for select using (
  is_active and (start_date is null or start_date <= now()) and (end_date is null or end_date > now())
);
drop policy if exists sponsors_public_read on public.sponsors;
create policy sponsors_public_read on public.sponsors for select using (
  is_active and (start_date is null or start_date <= now()) and (end_date is null or end_date > now())
);
drop policy if exists ad_campaigns_public_read on public.ad_campaigns;
create policy ad_campaigns_public_read on public.ad_campaigns for select using (
  is_active and (start_date is null or start_date <= now()) and (end_date is null or end_date > now())
);

-- Storage bucket for safe admin-managed commerce media.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('commerce-media','commerce-media',true,26214400,array['image/jpeg','image/png','image/webp','video/mp4','video/webm'])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists commerce_media_public_read on storage.objects;
create policy commerce_media_public_read on storage.objects for select using (bucket_id='commerce-media');
drop policy if exists commerce_media_admin_insert on storage.objects;
create policy commerce_media_admin_insert on storage.objects for insert to authenticated with check (bucket_id='commerce-media' and public.is_admin());
drop policy if exists commerce_media_admin_update on storage.objects;
create policy commerce_media_admin_update on storage.objects for update to authenticated using (bucket_id='commerce-media' and public.is_admin()) with check (bucket_id='commerce-media' and public.is_admin());
drop policy if exists commerce_media_admin_delete on storage.objects;
create policy commerce_media_admin_delete on storage.objects for delete to authenticated using (bucket_id='commerce-media' and public.is_admin());

-- Secure server-side order creation. Prices, discounts, stock and totals are never trusted from the browser.
create or replace function public.create_order_secure(
  p_first_name text,
  p_last_name text,
  p_phone text,
  p_email text,
  p_country text,
  p_city text,
  p_address text,
  p_street text,
  p_apartment text,
  p_items jsonb,
  p_idempotency_key text
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_existing public.orders%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_order_number text;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_unit numeric(12,2);
  v_discount numeric(12,2);
  v_line numeric(12,2);
  v_subtotal numeric(12,2) := 0;
  v_total_discount numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_primary_image text;
begin
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then raise exception 'Kërkesa e porosisë nuk është valide.'; end if;
  select * into v_existing from public.orders where idempotency_key=p_idempotency_key;
  if found then return jsonb_build_object('id',v_existing.id,'order_number',v_existing.order_number,'total',v_existing.total,'expected_delivery_at',v_existing.expected_delivery_at); end if;
  if length(trim(p_first_name))<2 or length(trim(p_last_name))<2 then raise exception 'Emri dhe mbiemri janë të detyrueshëm.'; end if;
  if p_phone !~ '^\+?[0-9][0-9 ()-]{6,19}$' then raise exception 'Numri i telefonit nuk është valid.'; end if;
  if coalesce(p_email,'')<>'' and p_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then raise exception 'Email-i nuk është valid.'; end if;
  if length(trim(p_country))<2 or length(trim(p_city))<2 or length(trim(p_address))<3 then raise exception 'Adresa e dërgesës nuk është e plotë.'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Shporta është bosh.'; end if;

  v_order_number := 'ORD-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.order_number_seq')::text,6,'0');
  insert into public.orders(id,order_number,customer_name,customer_email,first_name,last_name,phone,country,city,address,street,apartment,payment_method,status,subtotal,discount,total,expected_delivery_at,idempotency_key)
  values(v_order_id,v_order_number,trim(p_first_name)||' '||trim(p_last_name),nullif(lower(trim(coalesce(p_email,''))),''),trim(p_first_name),trim(p_last_name),trim(p_phone),trim(p_country),trim(p_city),trim(p_address),trim(coalesce(p_street,'')),trim(coalesce(p_apartment,'')),'cash','new',0,0,0,now()+interval '72 hours',p_idempotency_key);

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    if v_qty<1 or v_qty>99 then raise exception 'Sasia nuk është valide.'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and active=true for update;
    if not found then raise exception 'Një produkt nuk është më i disponueshëm.'; end if;
    if v_product.stock < v_qty then raise exception 'Stoku nuk është i mjaftueshëm për produktin %.',v_product.name_sq; end if;

    v_unit := v_product.price;
    v_discount := 0;
    if (v_product.discount_start is null or v_product.discount_start<=now()) and (v_product.discount_end is null or v_product.discount_end>now()) then
      if v_product.discount_percentage>0 then v_discount := round(v_unit*(v_product.discount_percentage/100),2);
      elsif v_product.discount_amount>0 then v_discount := least(v_product.discount_amount,v_unit); end if;
    end if;
    v_line := (v_unit-v_discount)*v_qty;
    select image_url into v_primary_image from public.product_images where product_id=v_product.id order by is_primary desc,sort_order limit 1;

    insert into public.order_items(order_id,product_id,product_name_snapshot,sku_snapshot,image_url_snapshot,quantity,unit_price,discount,line_total)
    values(v_order_id,v_product.id,v_product.name_sq,v_product.sku,coalesce(v_primary_image,'assets/'||v_product.image_key),v_qty,v_unit,v_discount*v_qty,v_line);
    update public.products set stock=stock-v_qty where id=v_product.id;
    v_subtotal := v_subtotal+(v_unit*v_qty);
    v_total_discount := v_total_discount+(v_discount*v_qty);
    v_total := v_total+v_line;
  end loop;

  update public.orders set subtotal=v_subtotal,discount=v_total_discount,total=v_total where id=v_order_id;
  return jsonb_build_object('id',v_order_id,'order_number',v_order_number,'subtotal',v_subtotal,'discount',v_total_discount,'total',v_total,'expected_delivery_at',now()+interval '72 hours');
exception when unique_violation then
  select * into v_existing from public.orders where idempotency_key=p_idempotency_key;
  return jsonb_build_object('id',v_existing.id,'order_number',v_existing.order_number,'total',v_existing.total,'expected_delivery_at',v_existing.expected_delivery_at);
end;
$$;
revoke all on function public.create_order_secure(text,text,text,text,text,text,text,text,text,jsonb,text) from public;
grant execute on function public.create_order_secure(text,text,text,text,text,text,text,text,text,jsonb,text) to anon, authenticated;

-- Admin dashboard statistics in one efficient query.
create or replace function public.admin_dashboard_stats()
returns jsonb language sql stable security definer set search_path=public as $$
  select case when public.is_admin() then jsonb_build_object(
    'orders',jsonb_build_object(
      'total',(select count(*) from orders),
      'new',(select count(*) from orders where status='new'),
      'confirmed',(select count(*) from orders where status='confirmed'),
      'preparing',(select count(*) from orders where status='preparing'),
      'shipped',(select count(*) from orders where status='shipped'),
      'delivered',(select count(*) from orders where status in ('delivered','completed')),
      'cancelled',(select count(*) from orders where status='cancelled')
    ),
    'products',jsonb_build_object(
      'total',(select count(*) from products),
      'active',(select count(*) from products where active),
      'out_of_stock',(select count(*) from products where stock<=0),
      'discounted',(select count(*) from products where discount_percentage>0 or discount_amount>0),
      'new',(select count(*) from products where is_new)
    ),
    'categories',jsonb_build_object(
      'total',(select count(*) from categories),
      'homepage',(select count(*) from categories where show_on_homepage and is_active)
    ),
    'advertising',jsonb_build_object(
      'sponsors',(select count(*) from sponsors where is_active and (end_date is null or end_date>now())),
      'campaigns',(select count(*) from ad_campaigns where is_active and (end_date is null or end_date>now()))
    )
  ) else null end;
$$;
revoke all on function public.admin_dashboard_stats() from public;
grant execute on function public.admin_dashboard_stats() to authenticated;
