-- auto-generated definition
create table cleaned_lot
(
    id                 bigint,
    datetime_created   timestamp,
    datetime_updated   timestamp,
    base_price         text,
    brand              text,
    contract_number    text,
    date               timestamp,
    lot                bigint,
    measure_unit       text,
    product_group_name text,
    product_name       text,
    product_type_name  text,
    seller_name        text,
    seller_region      text,
    session            bigint,
    set_volume_tons    text,
    sold_volume_tons   text,
    sold_volume_uzs    text
);

alter table cleaned_lot
    owner to postgres;

-- auto-generated definition
create table cleaned_organization
(
    id               bigint,
    datetime_created timestamp,
    datetime_updated timestamp,
    inn              text,
    name             text,
    type             text,
    warehouse1c_id   text,
    district_id      double precision
);

alter table cleaned_organization
    owner to postgres;

-- auto-generated definition
create table cleaned_personal
(
    id                     bigint,
    birth_date             text,
    document               text,
    expiry_date            text,
    first_name             text,
    issue_date             text,
    issued_by              text,
    last_name              text,
    middle_name            text,
    organization_name      text,
    organization_stir      text,
    passport_series_number text,
    position               text,
    position_count         double precision,
    stir                   text,
    region_id              integer
);

alter table cleaned_personal
    owner to postgres;

-- auto-generated definition
create table cleaned_region
(
    id               serial
        primary key,
    datetime_created timestamp default now(),
    datetime_updated timestamp default now(),
    name             text
);

alter table cleaned_region
    owner to postgres;

-- auto-generated definition
create table cleaned_sold_lot
(
    id                         bigint,
    datetime_created           timestamp,
    datetime_updated           timestamp,
    account                    text,
    bank_name                  text,
    bargain_status             text,
    buyer_address              text,
    buyer_inn                  text,
    buyer_name                 text,
    contract_name              text,
    contract_number            text,
    contract_type              bigint,
    currency                   text,
    delivery_date              date,
    delivery_date_deadline     bigint,
    lot_id                     double precision,
    measure_unit               text,
    mfo                        text,
    pay_date                   date,
    payment_date_deadline      bigint,
    price_per_contract         double precision,
    product_name               text,
    quantity                   bigint,
    quantity_in_lot            bigint,
    seller_address             text,
    seller_inn                 text,
    seller_name                text,
    session                    bigint,
    start_price                double precision,
    transaction_date           timestamp,
    transaction_number         text,
    transaction_sum            double precision,
    warehouse                  text,
    transaction_date_as_date   date,
    real_quantity              double precision,
    mxik_code                  text,
    transaction_sum_calculated double precision,
    real_quantity_for_amount   double precision,
    converted_measure_unit     text,
    product_main_category      text,
    mxik_name                  text,
    buyer_phone                text,
    seller_phone               text
);

alter table cleaned_sold_lot
    owner to postgres;

-- auto-generated definition
create table cleaned_transfer
(
    id                bigint not null
        primary key,
    datetime_created  timestamp,
    datetime_updated  timestamp,
    approved_date     timestamp,
    total_quantity    double precision,
    approved_user_id  bigint,
    from_warehouse_id bigint,
    to_warehouse_id   bigint,
    organization_id   bigint,
    period            date,
    lot_id            bigint,
    product_name      varchar,
    transfer_status   varchar,
    driver_name       varchar,
    driver_pinfl      varchar,
    transport_number  varchar,
    transport_model   varchar,
    deliverer_pinfl   varchar
);

alter table cleaned_transfer
    owner to postgres;

-- auto-generated definition
create table cleaned_warehouse
(
    id               bigint not null
        primary key,
    datetime_created timestamp,
    datetime_updated timestamp,
    organization_id  bigint,
    latitude         double precision,
    longitude        double precision,
    name             varchar,
    warehouse1cid    varchar,
    warehouse_type   varchar
);

alter table cleaned_warehouse
    owner to postgres;

