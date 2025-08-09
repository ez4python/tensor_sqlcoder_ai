--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: income_outcome_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.income_outcome_type AS ENUM (
    'IN',
    'OUT'
);


ALTER TYPE public.income_outcome_type OWNER TO postgres;

--
-- Name: update_warehouse_amount(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_warehouse_amount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    WITH balance_calc AS (
        SELECT
            o.id as organization_id,
            COALESCE(from_warehouse_id, to_warehouse_id) AS warehouse_id,
            product_id,
            COALESCE(SUM(to_amount), 0) - COALESCE(SUM(from_amount), 0) AS quantity
        FROM (
            SELECT
                from_warehouse_id,
                NULL::bigint AS to_warehouse_id,
                factory_id,
                product_id,
                case when transfer.transfer_status not in ('ON_THE_ROAD', 'NEW') and transfer.status != 'CANCELLED' then total_quantity else 0 end AS from_amount,
                period,
                0 AS to_amount
            FROM transfer where transfer.transfer_status !='ON_THE_ROAD'
            UNION ALL
            SELECT
                NULL::bigint AS from_warehouse_id,
                to_warehouse_id,
                factory_id,
                product_id,
                0 AS from_amount,
                period,
                case when transfer.transfer_status not in ('ON_THE_ROAD', 'NEW') and transfer.status != 'CANCELLED' then total_quantity else 0 end AS to_amount
            FROM transfer where transfer.transfer_status !='ON_THE_ROAD'
        ) t
        LEFT JOIN warehouse w ON w.id = COALESCE(t.from_warehouse_id, t.to_warehouse_id)
        LEFT JOIN organization o ON o.id = t.factory_id
        GROUP BY
            o.id, COALESCE(from_warehouse_id, to_warehouse_id), product_id
    )

    INSERT INTO warehouse_amount (datetime_created, datetime_updated, organization_id, warehouse_id, product_id, quantity)
    SELECT
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        bc.organization_id,
        bc.warehouse_id,
        cast(bc.product_id as bigint),
        sum(bc.quantity)
    FROM balance_calc bc
    JOIN organization o ON o.id = bc.organization_id
    group by bc.organization_id, bc.warehouse_id, bc.product_id
    ON CONFLICT (organization_id, warehouse_id, product_id)
    DO UPDATE SET
        quantity = EXCLUDED.quantity,
        datetime_updated = CURRENT_TIMESTAMP;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_warehouse_amount() OWNER TO postgres;

--
-- Name: update_warehouse_balance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_warehouse_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- When a transfer is added or updated
    WITH balance_calc AS (
        SELECT
            o.id as organization_id,
            COALESCE(from_warehouse_id, to_warehouse_id) AS warehouse_id,
            product_id,
            product_name,
            COALESCE(SUM(to_amount), 0) - COALESCE(SUM(from_amount), 0) AS quantity
        FROM (
            SELECT
                from_warehouse_id,
                NULL::bigint AS to_warehouse_id,
                organization_id,
                product_id,
                product_name,
                case when status!='CANCELLED' then total_quantity else 0 end AS from_amount,
                period,
                0 AS to_amount
            FROM transfer where status!='ON_THE_ROAD' and organization_id is not null
            UNION ALL
            SELECT
                NULL::bigint AS from_warehouse_id,
                to_warehouse_id,
                organization_id,
                product_id,
                product_name,
                0 AS from_amount,
                period,
                case when status!='CANCELLED' then total_quantity else 0 end AS to_amount
            FROM transfer where status!='ON_THE_ROAD' and organization_id is not null
        ) t
        LEFT JOIN warehouse w ON w.id = COALESCE(t.from_warehouse_id, t.to_warehouse_id)
        LEFT JOIN organization o ON o.id = t.organization_id::bigint
        GROUP BY
            o.id, COALESCE(from_warehouse_id, to_warehouse_id), product_id, product_name
    )

    -- Update or insert into warehouse_balance table
    INSERT INTO warehouse_balance (datetime_created, datetime_updated, organization_id, warehouse_id, product_id, product_name, quantity)
    SELECT
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        organization_id,
        warehouse_id,
        product_id,
        product_name,
        quantity
    FROM balance_calc
    ON CONFLICT (organization_id, warehouse_id, product_id, product_name)
    DO UPDATE SET
        quantity = EXCLUDED.quantity,
        datetime_updated = CURRENT_TIMESTAMP;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_warehouse_balance() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agro_fertilizer_demand; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.agro_fertilizer_demand (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    amofos_amount double precision,
    amofos_delivery double precision,
    boshqalar_delivery double precision,
    district_name character varying(255),
    farmer_name character varying(255),
    harvest_name character varying(255),
    has_farmer_data boolean,
    karbamid_amount double precision,
    karbamid_delivery double precision,
    outline_bonitet double precision,
    region_name character varying(255),
    selitra_amount double precision,
    selitra_delivery double precision,
    text_number bigint,
    total_area double precision
);


ALTER TABLE public.agro_fertilizer_demand OWNER TO postgres;

--
-- Name: all_investment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.all_investment (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    text character varying(255)
);


ALTER TABLE public.all_investment OWNER TO postgres;

--
-- Name: application; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.application (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    amount double precision,
    app_date date,
    c_type character varying(255),
    contract_number character varying(255),
    court_name character varying(255),
    currency_code character varying(255),
    description character varying(255),
    inn character varying(255),
    kontragent character varying(255),
    debt_credit_1c_id bigint,
    organization_id bigint,
    application_number character varying(255),
    document_path character varying(255),
    create_by bigint
);


ALTER TABLE public.application OWNER TO postgres;

--
-- Name: application_divorce; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.application_divorce (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    amount double precision,
    divorce_date date,
    status character varying(255),
    application_id bigint,
    create_by bigint,
    application_divorce_document_path character varying(255),
    application_payment_document_path character varying(255),
    application_payment_number character varying(255),
    CONSTRAINT application_divorce_status_check CHECK (((status)::text = ANY (ARRAY[('SATISFIED'::character varying)::text, ('PARTIALLY_SATISFIED'::character varying)::text, ('REJECTED'::character varying)::text])))
);


ALTER TABLE public.application_divorce OWNER TO postgres;

--
-- Name: argus; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.argus (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date date,
    description character varying(255),
    value double precision,
    short_description character varying(255) DEFAULT NULL::character varying,
    ru_description character varying(255) DEFAULT NULL::character varying,
    ru_short_description character varying(255) DEFAULT NULL::character varying
);


ALTER TABLE public.argus OWNER TO postgres;

--
-- Name: article; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.article (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255),
    parent_id bigint,
    c1id character varying(255),
    organization_id bigint
);


ALTER TABLE public.article OWNER TO postgres;

--
-- Name: attachment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attachment (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    file_url character varying(255),
    warehouse_id bigint,
    camera_id bigint
);


ALTER TABLE public.attachment OWNER TO postgres;

--
-- Name: birja_lot_import_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.birja_lot_import_progress (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    from_date date,
    from_date_str character varying(255),
    import_type character varying(255),
    multi_day_import boolean DEFAULT false,
    received_count integer,
    save_count integer,
    to_date date,
    to_date_str character varying(255),
    update_count integer,
    exceptions text,
    create_by bigint
);


ALTER TABLE public.birja_lot_import_progress OWNER TO postgres;

--
-- Name: camera; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.camera (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    camera_id character varying(255) NOT NULL,
    host character varying(255),
    password character varying(255),
    path character varying(255),
    port character varying(255),
    title character varying(255),
    url character varying(255) NOT NULL,
    username character varying(255),
    investment_id bigint,
    warehouse_id bigint
);


ALTER TABLE public.camera OWNER TO postgres;

--
-- Name: car; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.car (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    car_brand character varying(255),
    car_data character varying(255),
    car_model character varying(255),
    car_number character varying(255)
);


ALTER TABLE public.car OWNER TO postgres;

--
-- Name: car_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.car ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.car_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: carrier; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.carrier (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    carrier_address character varying(255),
    carrier_country character varying(255),
    carrier_name character varying(255),
    cars_id bigint,
    delivers_id bigint
);


ALTER TABLE public.carrier OWNER TO postgres;

--
-- Name: carrier_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.carrier ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.carrier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: check_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.check_status (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    comment character varying(255),
    local_id bigint,
    number integer,
    success boolean
);


ALTER TABLE public.check_status OWNER TO postgres;

--
-- Name: check_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.check_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.check_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: connection_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.connection_status (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    camera1connection boolean,
    camera2connection boolean,
    camera3connection boolean,
    gate1connection boolean,
    gate2connection boolean,
    is_connected boolean,
    kppgate1connection boolean,
    kppgate2connection boolean,
    sensor1connection boolean,
    sensor2connection boolean,
    sensor3connection boolean
);


ALTER TABLE public.connection_status OWNER TO postgres;

--
-- Name: connection_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.connection_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.connection_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contr_agent; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contr_agent (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    inn character varying(255),
    name character varying(255),
    district_id bigint,
    region_id bigint
);


ALTER TABLE public.contr_agent OWNER TO postgres;

--
-- Name: contract; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contract (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    enter_date character varying(255),
    inn character varying(255),
    lot character varying(255),
    lot_name character varying(255),
    measure_unit character varying(255),
    name text,
    number character varying(255),
    region character varying(255),
    seller_name character varying(255),
    sklad_name text,
    status character varying(255),
    inn_sklad character varying(255),
    spets character varying(255),
    create_by bigint
);


ALTER TABLE public.contract OWNER TO postgres;

--
-- Name: country_code; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.country_code (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    alpha2 character varying(255),
    alpha3 character varying(255),
    code character varying(255),
    long_name character varying(255),
    short_name character varying(255),
    create_by bigint
);


ALTER TABLE public.country_code OWNER TO postgres;

--
-- Name: court_case; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.court_case (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    case_name character varying(255),
    case_request_document_file_url character varying(255),
    case_resolve_document_file_url character varying(255),
    court_id character varying(255),
    court_instance_id character varying(255),
    court_instance_name character varying(255),
    court_name character varying(255),
    credit_debt_amount real,
    credit_debt_amount_to_be_collected real,
    organization_id character varying(255),
    organization_name character varying(255),
    submitted_case_credit_debt_amount real,
    create_by bigint
);


ALTER TABLE public.court_case OWNER TO postgres;

--
-- Name: cron_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cron_status (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date_time timestamp(6) without time zone,
    text text
);


ALTER TABLE public.cron_status OWNER TO postgres;

--
-- Name: crop; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crop (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    area character varying(255),
    crop_id bigint,
    cropagro_link character varying(255),
    farmer_cad_number character varying(255),
    farmer_tax_number bigint,
    harvest_code bigint,
    harvest_generation_code integer,
    harvest_generation_name character varying(255),
    harvest_name character varying(255),
    harvest_sort_code integer,
    harvest_sort_name character varying(255),
    harvest_type_code character varying(255),
    harvest_type_name character varying(255),
    harvest_year integer,
    outline_bonitet integer,
    outline_bonitet_contour_number integer,
    place_category_code character varying(255),
    place_category_name character varying(255),
    place_code integer,
    place_name character varying(255),
    region_code integer,
    region_name character varying(255),
    watering integer,
    district_code integer,
    district_name character varying(255),
    farmer_name character varying(255),
    create_by bigint
);


ALTER TABLE public.crop OWNER TO postgres;

--
-- Name: crop_and_sold_lot_dto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crop_and_sold_lot_dto (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    area character varying(255),
    bargain_status character varying(255),
    buyer_inn character varying(255),
    buyer_name character varying(255),
    contract_name character varying(255),
    contract_number character varying(255),
    contract_type integer,
    converted_measure_unit character varying(255),
    crop_id bigint,
    currency character varying(255),
    district_code integer,
    district_name character varying(255),
    farmer_cad_number character varying(255),
    farmer_name character varying(255),
    farmer_tax_number bigint,
    harvest_generation_name character varying(255),
    harvest_name character varying(255),
    harvest_sort_code integer,
    harvest_sort_name character varying(255),
    harvest_type_name character varying(255),
    harvest_year integer,
    mxik_code character varying(255),
    place_category_name character varying(255),
    place_code integer,
    place_name character varying(255),
    price_per_contract double precision,
    product_group_name character varying(255),
    product_name character varying(255),
    real_quantity double precision,
    real_quantity_for_amount double precision,
    region_code integer,
    region_name character varying(255),
    seller_inn character varying(255),
    seller_name character varying(255),
    session integer,
    transaction_date_as_date date,
    transaction_number character varying(255),
    transaction_sum_calculated double precision,
    watering integer
);


ALTER TABLE public.crop_and_sold_lot_dto OWNER TO postgres;

--
-- Name: crop_and_sold_lotdto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crop_and_sold_lotdto (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    area character varying(255),
    bargain_status character varying(255),
    buyer_inn character varying(255),
    buyer_name character varying(255),
    contract_name character varying(255),
    contract_number character varying(255),
    contract_type integer,
    converted_measure_unit character varying(255),
    crop_id bigint,
    currency character varying(255),
    district_code integer,
    district_name character varying(255),
    farmer_cad_number character varying(255),
    farmer_name character varying(255),
    farmer_tax_number bigint,
    harvest_generation_name character varying(255),
    harvest_name character varying(255),
    harvest_sort_code integer,
    harvest_sort_name character varying(255),
    harvest_type_name character varying(255),
    harvest_year integer,
    mxik_code character varying(255),
    place_category_name character varying(255),
    place_code integer,
    place_name character varying(255),
    price_per_contract double precision,
    product_group_name character varying(255),
    product_name character varying(255),
    real_quantity double precision,
    real_quantity_for_amount double precision,
    region_code integer,
    region_name character varying(255),
    seller_inn character varying(255),
    seller_name character varying(255),
    session integer,
    transaction_date_as_date date,
    transaction_number character varying(255),
    transaction_sum_calculated double precision,
    watering integer,
    create_by bigint
);


ALTER TABLE public.crop_and_sold_lotdto OWNER TO postgres;

--
-- Name: daily_birja_selling; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.daily_birja_selling (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    days date,
    name text,
    price double precision,
    type character varying(255),
    weight double precision,
    CONSTRAINT daily_birja_selling_type_check CHECK (((type)::text = ANY (ARRAY[('AZOTLI'::character varying)::text, ('FOSFORLI'::character varying)::text, ('KALIYLI'::character varying)::text, ('MIKROUZV'::character varying)::text, ('KOMPLEKS'::character varying)::text, ('ORGANIK_MINERAL'::character varying)::text, ('BOSHQA'::character varying)::text])))
);


ALTER TABLE public.daily_birja_selling OWNER TO postgres;

--
-- Name: debtor_creditor1c; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.debtor_creditor1c (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    amount double precision,
    contract character varying(255),
    contract_id uuid,
    currency_amount double precision,
    currency_code character varying(255),
    inn character varying(255),
    last_operation_date date,
    name character varying(255),
    organization_id bigint,
    type character varying(255),
    date_created date NOT NULL,
    create_by bigint,
    documents_created_date date
);


ALTER TABLE public.debtor_creditor1c OWNER TO postgres;

--
-- Name: debtor_creditor1cimport_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.debtor_creditor1cimport_progress (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    organization_id bigint,
    total_count integer,
    create_by bigint,
    request_details character varying(255)
);


ALTER TABLE public.debtor_creditor1cimport_progress OWNER TO postgres;

--
-- Name: deliver; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deliver (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    deliver_name character varying(255),
    deliver_passport_data character varying(255),
    deliver_surname character varying(255)
);


ALTER TABLE public.deliver OWNER TO postgres;

--
-- Name: deliver_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.deliver ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.deliver_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: department; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department (
    id bigint NOT NULL,
    name character varying(255),
    parent_id bigint,
    organization_id bigint,
    department_type_id bigint,
    c1id character varying(255),
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


ALTER TABLE public.department OWNER TO postgres;

--
-- Name: department_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.department ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: department_personal; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department_personal (
    department_id bigint NOT NULL,
    personal_id bigint NOT NULL
);


ALTER TABLE public.department_personal OWNER TO postgres;

--
-- Name: department_personals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department_personals (
    department_id bigint NOT NULL,
    personals_id bigint NOT NULL
);


ALTER TABLE public.department_personals OWNER TO postgres;

--
-- Name: department_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department_types (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone,
    description character varying(255),
    organization_id bigint,
    type_name character varying(255) NOT NULL
);


ALTER TABLE public.department_types OWNER TO postgres;

--
-- Name: department_types_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.department_types ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.department_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: district; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.district (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255),
    region_id bigint,
    faktura_district_code bigint,
    name_uz character varying(255),
    faktura_district_name character varying(255),
    create_by bigint,
    soato bigint
);


ALTER TABLE public.district OWNER TO postgres;

--
-- Name: doverennost_file; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doverennost_file (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    document_date date,
    document_number character varying(255),
    file_url character varying(255)
);


ALTER TABLE public.doverennost_file OWNER TO postgres;

--
-- Name: driver; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.driver (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    driver_phone_number character varying(255),
    transport_driver_name character varying(255),
    transport_model character varying(255),
    transport_number character varying(255),
    transport_owner_pinfl character varying(255),
    navoiy_azot_transfer_id bigint
);


ALTER TABLE public.driver OWNER TO postgres;

--
-- Name: driver_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.driver ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.driver_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: drivers_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.drivers_info (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone,
    driver_name character varying(255),
    phone_number character varying(255),
    pinfl character varying(255) NOT NULL,
    transport_model character varying(255),
    transport_number character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone,
    district_id bigint,
    region_id bigint
);


ALTER TABLE public.drivers_info OWNER TO postgres;

--
-- Name: drivers_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.drivers_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.drivers_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: eimzo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eimzo (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    data character varying(255),
    director_name character varying(255),
    director_pinfl character varying(255),
    error_code integer,
    error_message character varying(255),
    is_individual_entrepreneur boolean,
    is_legal boolean,
    name character varying(255),
    pinfl character varying(255),
    serial_number character varying(255),
    success boolean NOT NULL,
    "timestamp" character varying(255),
    tin character varying(255),
    tin_pinfl character varying(255),
    user_id bigint,
    secret_key character varying(255),
    create_by bigint
);


ALTER TABLE public.eimzo OWNER TO postgres;

--
-- Name: electric_meters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.electric_meters (
    id bigint NOT NULL,
    account_id character varying(255) NOT NULL,
    created_at timestamp(6) without time zone,
    freeze_date date,
    full_name character varying(255),
    meter_no character varying(255),
    p0300 double precision,
    p0310 double precision,
    p0320 double precision,
    p0330 double precision,
    p0340 double precision,
    p0400 double precision,
    p0410 double precision,
    p0420 double precision,
    p0430 double precision,
    p0440 double precision,
    p0500 double precision,
    p0510 double precision,
    p0520 double precision,
    p0530 double precision,
    p0540 double precision,
    p0600 double precision,
    p0610 double precision,
    p0620 double precision,
    p0630 double precision,
    p0640 double precision,
    rate integer,
    soato character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone
);


ALTER TABLE public.electric_meters OWNER TO postgres;

--
-- Name: electric_meters_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.electric_meters ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.electric_meters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: electricity_legal_entity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.electricity_legal_entity (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    address character varying(255),
    contract_date date,
    contract_number character varying(255),
    customer_code character varying(255),
    customer_name character varying(255),
    inn character varying(255),
    kadastr_code character varying(255),
    last_payment bigint,
    last_payment_date date,
    prosrochka_in bigint,
    saldo bigint,
    soato character varying(255),
    meters_id bigint,
    payments_id bigint,
    readings_id bigint,
    saldo_period_id bigint
);


ALTER TABLE public.electricity_legal_entity OWNER TO postgres;

--
-- Name: employee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    count integer,
    date date,
    type character varying(255),
    staff_technic_id bigint,
    type_id bigint
);


ALTER TABLE public.employee OWNER TO postgres;

--
-- Name: employee_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee_type (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255)
);


ALTER TABLE public.employee_type OWNER TO postgres;

--
-- Name: enakladnoy_shipment_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enakladnoy_shipment_status (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    code integer,
    status text
);


ALTER TABLE public.enakladnoy_shipment_status OWNER TO postgres;

--
-- Name: enaklodnoy; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enaklodnoy (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    description character varying(255),
    gu12id bigint,
    nomenclature_code integer,
    nomenclature_name character varying(255),
    plan_date timestamp(6) without time zone,
    receive_stations character varying(255),
    send_station_code character varying(255),
    send_station_name character varying(255),
    status_code integer,
    type integer,
    unladen_wagon_count integer,
    unladen_weight double precision,
    wagon_count integer,
    weight double precision
);


ALTER TABLE public.enaklodnoy OWNER TO postgres;

--
-- Name: enaklodnoy_shipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enaklodnoy_shipment (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    create_date timestamp(6) without time zone,
    delivery_date timestamp(6) without time zone,
    gu29id bigint,
    is_load boolean,
    loaded_date timestamp(6) without time zone,
    otpravka_number character varying(255),
    receive_station_code character varying(255),
    receive_station_name character varying(255),
    receiver_code integer,
    receiver_name character varying(255),
    send_station_code character varying(255),
    send_station_name character varying(255),
    sender_code integer,
    sender_name character varying(255),
    status_code integer,
    tin character varying(255),
    total_price double precision,
    wagons_count integer,
    weight double precision,
    create_by bigint
);


ALTER TABLE public.enaklodnoy_shipment OWNER TO postgres;

--
-- Name: enaklodnoy_wagon; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enaklodnoy_wagon (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    description character varying(255),
    gu12id bigint,
    nomenclature_code integer,
    nomenclature_name character varying(255),
    plan_date timestamp(6) without time zone,
    receive_stations character varying(255),
    send_station_code character varying(255),
    send_station_name character varying(255),
    status_code integer,
    tin character varying(255),
    type integer,
    unladen_wagon_count integer,
    unladen_weight double precision,
    wagon_count integer,
    weight double precision,
    create_by bigint
);


ALTER TABLE public.enaklodnoy_wagon OWNER TO postgres;

--
-- Name: export_applications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.export_applications (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    additional_name character varying(255),
    agreement_result boolean,
    codtnv character varying(255),
    commercial_application_url character varying(255),
    confirmator_role character varying(255),
    confirmatory_name character varying(255),
    contract_description character varying(255),
    contract_url character varying(255),
    contractor_document_url character varying(255),
    currency character varying(255),
    document_description character varying(255),
    inn character varying(255),
    is_confirmed boolean,
    organization_name character varying(255),
    price double precision,
    received_message_url character varying(255),
    reply_letter_signer character varying(255),
    sending_method character varying(255),
    CONSTRAINT export_applications_confirmator_role_check CHECK (((confirmator_role)::text = ANY (ARRAY[('DIRECTOR'::character varying)::text, ('DEPUTY_DIRECTOR'::character varying)::text]))),
    CONSTRAINT export_applications_currency_check CHECK (((currency)::text = ANY (ARRAY[('DOLLAR'::character varying)::text, ('SOM'::character varying)::text, ('EURO'::character varying)::text]))),
    CONSTRAINT export_applications_reply_letter_signer_check CHECK (((reply_letter_signer)::text = ANY (ARRAY[('DIRECTOR'::character varying)::text, ('DEPUTY_DIRECTOR'::character varying)::text]))),
    CONSTRAINT export_applications_sending_method_check CHECK (((sending_method)::text = ANY (ARRAY[('EMAIL'::character varying)::text, ('TELEGRAM'::character varying)::text, ('WHATSAPP'::character varying)::text])))
);


ALTER TABLE public.export_applications OWNER TO postgres;

--
-- Name: export_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.export_data (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    concinge_address character varying(255),
    concinge_country character varying(255),
    concinge_name character varying(255),
    delivery_country character varying(255),
    delivery_pleace character varying(255),
    document_data timestamp(6) without time zone,
    document_invoice character varying(255),
    document_tir character varying(255),
    establish_data timestamp(6) without time zone,
    establish_plase character varying(255),
    goods_brand character varying(255),
    goods_gods_code character varying(255),
    goods_hs_code character varying(255),
    goods_marks character varying(255),
    goods_number character varying(255),
    gross_volume character varying(255),
    gross_weight character varying(255),
    package_number character varying(255),
    package_type character varying(255),
    paid_amount character varying(255),
    paid_consignee character varying(255),
    paid_currency character varying(255),
    paid_sender character varying(255),
    sender_address character varying(255),
    sender_country character varying(255),
    sender_instructions character varying(255),
    sender_name character varying(255),
    special_agreements character varying(255),
    statistical_number character varying(255),
    taking_county character varying(255),
    taking_data timestamp(6) without time zone,
    taking_place character varying(255),
    carrier_id bigint
);


ALTER TABLE public.export_data OWNER TO postgres;

--
-- Name: export_data_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.export_data ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.export_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: faktura_uz_document; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.faktura_uz_document (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    contract text,
    contractor_branch_code character varying(255),
    contractor_branch_name character varying(255),
    contractor_inn character varying(255),
    contractor_member_branch_code character varying(255),
    contractor_member_branch_name character varying(255),
    contractor_member_inn character varying(255),
    contractor_member_name character varying(255),
    contractor_name character varying(255),
    created_date_time bigint,
    file_name character varying(255),
    is_agreement_approved boolean,
    is_inbox boolean,
    is_new boolean,
    organization_id bigint,
    organization_inn character varying(255),
    owner_member_branch_code character varying(255),
    owner_member_branch_name character varying(255),
    owner_member_inn character varying(255),
    owner_member_name character varying(255),
    registry_file_name character varying(255),
    registry_id character varying(255),
    registry_unique_id character varying(255),
    roaming_uid character varying(255),
    status integer,
    title character varying(255),
    total_price character varying(255),
    type integer,
    unique_id character varying(255),
    updated_date_time bigint,
    created_date_time_as_date_time timestamp(6) without time zone,
    updated_date_time_as_date_time timestamp(6) without time zone,
    create_by bigint
);


ALTER TABLE public.faktura_uz_document OWNER TO postgres;

--
-- Name: faktura_uz_document_content; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.faktura_uz_document_content (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    accountant character varying(255),
    contract_date character varying(255),
    contract_number text,
    contractor_account character varying(255),
    contractor_accountant character varying(255),
    contractor_address text,
    contractor_bank character varying(255),
    contractor_branch_code character varying(255),
    contractor_branch_name character varying(255),
    contractor_director character varying(255),
    contractor_email character varying(255),
    contractor_inn character varying(255),
    contractor_mfo character varying(255),
    contractor_name character varying(255),
    contractor_nds_code character varying(255),
    contractor_oked character varying(255),
    contractor_okonx character varying(255),
    contractor_phone character varying(255),
    contractor_unit_id character varying(255),
    date_of_issue character varying(255),
    deliverer character varying(255),
    deliverer_inn character varying(255),
    deliverer_passport_serial_char character varying(255),
    deliverer_passport_serial_number character varying(255),
    deliverer_roaming_id character varying(255),
    director character varying(255),
    document_date character varying(255),
    document_number character varying(255),
    document_valid_date character varying(255),
    document_values_for character varying(255),
    external_id character varying(255),
    file character varying(255),
    is_new_identity boolean,
    issued_by character varying(255),
    owner_account character varying(255),
    owner_address character varying(255),
    owner_bank character varying(255),
    owner_branch_code character varying(255),
    owner_branch_name character varying(255),
    owner_email character varying(255),
    owner_inn character varying(255),
    owner_mfo character varying(255),
    owner_name character varying(255),
    owner_nds_code character varying(255),
    owner_oked character varying(255),
    owner_okonx character varying(255),
    owner_phone character varying(255),
    owner_unit_id character varying(255),
    "position" character varying(255),
    releaser character varying(255),
    roaming_id character varying(255),
    services_roaming_id character varying(255),
    oaming_uid character varying(255),
    unique_id character varying(255),
    roaming_uid character varying(255),
    create_by bigint
);


ALTER TABLE public.faktura_uz_document_content OWNER TO postgres;

--
-- Name: faktura_uz_document_content_product; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.faktura_uz_document_content_product (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date date,
    organization_id bigint,
    organization_inn character varying(255),
    organization_name character varying(255),
    price double precision,
    product_mxik_code character varying(255),
    product_mxik_name text,
    quantity double precision,
    unique_id character varying(255),
    contractor_inn character varying(255),
    contractor_name character varying(255),
    owner_inn character varying(255),
    owner_name character varying(255),
    delivery_cost double precision,
    delivery_tax_rate_with_taxes double precision,
    vat_amount double precision,
    vat_rate integer,
    invoice_contract_date date,
    invoice_contract_number character varying(255),
    invoice_date date,
    invoice_number character varying(255),
    measurement character varying(255),
    create_by bigint
);


ALTER TABLE public.faktura_uz_document_content_product OWNER TO postgres;

--
-- Name: faktura_uz_documnet_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.faktura_uz_documnet_status (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    code character varying(255),
    description character varying(255),
    status_id integer,
    create_by bigint
);


ALTER TABLE public.faktura_uz_documnet_status OWNER TO postgres;

--
-- Name: faktura_uz_import_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.faktura_uz_import_progress (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    cron_interval character varying(255),
    document_types character varying(255),
    exceptions text,
    from_date timestamp(6) without time zone,
    from_date_str character varying(255),
    import_type character varying(255),
    inbox_types character varying(255),
    multi_day_import boolean DEFAULT false,
    received_count integer,
    save_count integer,
    to_date timestamp(6) without time zone,
    to_date_str character varying(255),
    total_count bigint,
    total_price double precision,
    update_count integer,
    organization_id bigint
);


ALTER TABLE public.faktura_uz_import_progress OWNER TO postgres;

--
-- Name: faktura_uz_params; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.faktura_uz_params (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    inn character varying(255),
    login character varying(255),
    organization_id bigint,
    organization_name character varying(255),
    password character varying(255),
    create_by bigint
);


ALTER TABLE public.faktura_uz_params OWNER TO postgres;

--
-- Name: farmer_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.farmer_data (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    inn character varying(255),
    text character varying(255)
);


ALTER TABLE public.farmer_data OWNER TO postgres;

--
-- Name: fcm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fcm (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    fcm_token character varying(255),
    user_id bigint,
    create_by bigint
);


ALTER TABLE public.fcm OWNER TO postgres;

--
-- Name: funding_sources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.funding_sources (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    source_current_year double precision,
    source_growth_percent double precision,
    source_name character varying(255),
    source_next_year double precision,
    all_investment_id bigint
);


ALTER TABLE public.funding_sources OWNER TO postgres;

--
-- Name: general_invest; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.general_invest (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    amount character varying(255),
    count character varying(255),
    paid_amount character varying(255),
    value character varying(255),
    organization_id bigint
);


ALTER TABLE public.general_invest OWNER TO postgres;

--
-- Name: gov_goods; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gov_goods (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    additional_unit character varying(255),
    code_tiftn character varying(255),
    date character varying(255),
    ekim_country character varying(255),
    mode character varying(255),
    name_goods text,
    net_mass double precision,
    organization1name character varying(255),
    organization2name character varying(255),
    organization_tin character varying(255),
    purpose character varying(255),
    unit character varying(255),
    value double precision,
    create_by bigint
);


ALTER TABLE public.gov_goods OWNER TO postgres;

--
-- Name: household_response; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.household_response (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    adress character varying(255),
    askue boolean,
    balance_customer bigint,
    contract_date character varying(255),
    contract_number character varying(255),
    customer_code character varying(255),
    customer_type character varying(255),
    fio character varying(255),
    inn character varying(255),
    kadastr_code character varying(255),
    kf_tr character varying(255),
    last_payment character varying(255),
    last_payment_date character varying(255),
    last_pok integer,
    last_pok_date character varying(255),
    maxall_name character varying(255),
    meter_date character varying(255),
    meter_no character varying(255),
    meter_rz integer,
    meter_type character varying(255),
    passport_number character varying(255),
    phone_mobile character varying(255),
    phone_mobiled character varying(255),
    pinfl character varying(255),
    soato character varying(255),
    tarif_price integer,
    other_docs_id bigint,
    payments_id bigint,
    readings_id bigint,
    saldo_period_id bigint
);


ALTER TABLE public.household_response OWNER TO postgres;

--
-- Name: hudud_gaz_gas_meter_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hudud_gaz_gas_meter_info (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    created_date date,
    gas_consume integer,
    meter_statuses_name character varying(255),
    meter_types_name character varying(255),
    org_customer_code character varying(255),
    org_gas_sensors character varying(255),
    org_gas_sensors_id character varying(255),
    org_gas_sensors_name character varying(255),
    org_gas_sensors_status character varying(255),
    reading_date date,
    reading_value character varying(255)
);


ALTER TABLE public.hudud_gaz_gas_meter_info OWNER TO postgres;

--
-- Name: hudud_gaz_gas_meter_readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hudud_gaz_gas_meter_readings (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    created_date character varying(255),
    gas_consume double precision,
    meter_statuses_name character varying(255),
    meter_types_name character varying(255),
    org_customer_code character varying(255),
    org_gas_sensors character varying(255),
    org_gas_sensors_id bigint,
    org_gas_sensors_name character varying(255),
    org_gas_sensors_status character varying(255),
    reading_date date,
    reading_value integer
);


ALTER TABLE public.hudud_gaz_gas_meter_readings OWNER TO postgres;

--
-- Name: hudud_gaz_org_customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hudud_gaz_org_customer (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    branch_id integer,
    branch_name character varying(255),
    contract_date character varying(255),
    contract_number character varying(255),
    contract_status character varying(255),
    inn character varying(255),
    org_activitiyes character varying(255),
    org_category character varying(255),
    org_customer character varying(255),
    org_customer_code character varying(255),
    pinfl character varying(255),
    create_by bigint
);


ALTER TABLE public.hudud_gaz_org_customer OWNER TO postgres;

--
-- Name: implementation_projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.implementation_projects (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    implementation_current_year double precision,
    implementation_growth_percent double precision,
    implementation_next_year double precision,
    indicator character varying(255),
    all_investment_id bigint
);


ALTER TABLE public.implementation_projects OWNER TO postgres;

--
-- Name: import_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.import_log (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    action character varying(255),
    cron_type character varying(255),
    date_time timestamp(6) without time zone,
    date_time_type character varying(255),
    log_id bigint
);


ALTER TABLE public.import_log OWNER TO postgres;

--
-- Name: income_outcome; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.income_outcome (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date date,
    "timestamp" timestamp(6) without time zone,
    type character varying(255),
    personal_id bigint,
    turniket_name character varying(255),
    CONSTRAINT income_outcome_type_check CHECK (((type)::text = ANY (ARRAY[('IN'::character varying)::text, ('OUT'::character varying)::text])))
);


ALTER TABLE public.income_outcome OWNER TO postgres;

--
-- Name: investment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    april double precision,
    august double precision,
    december double precision,
    duration_days bigint,
    end_date date,
    february double precision,
    january double precision,
    july double precision,
    june double precision,
    march double precision,
    may double precision,
    name text,
    november double precision,
    october double precision,
    provider text,
    september double precision,
    start_date date,
    year integer,
    district_id bigint,
    investment_step_id bigint NOT NULL,
    amount double precision,
    status character varying(255),
    create_by bigint,
    CONSTRAINT investment_status_check CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('COMPLETED'::character varying)::text, ('LATER'::character varying)::text])))
);


ALTER TABLE public.investment OWNER TO postgres;

--
-- Name: investment_comment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_comment (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    comment_date date,
    text character varying(255),
    url text,
    investment_id bigint,
    create_by bigint
);


ALTER TABLE public.investment_comment OWNER TO postgres;

--
-- Name: investment_funding_source_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_funding_source_info (
    doc_id bigint NOT NULL,
    bank_funds double precision,
    bank_remaind double precision,
    bankf_invest double precision,
    bankf_remaind double precision,
    created_at date,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    dev_funds double precision,
    dev_remaind double precision,
    foreign_invest double precision,
    foreign_remaind double precision,
    gov_credit double precision,
    gov_remaind double precision,
    own_cost double precision,
    own_remaind double precision,
    project_name character varying(255),
    id bigint NOT NULL
);


ALTER TABLE public.investment_funding_source_info OWNER TO postgres;

--
-- Name: investment_funding_source_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.investment_funding_source_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.investment_funding_source_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: investment_project; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_project (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name text,
    organization_id bigint,
    amount double precision,
    complete_percent double precision,
    end_date date,
    start_date date,
    paid_amount double precision,
    district character varying(255),
    partner character varying(255),
    partner_country character varying(255),
    partner_name character varying(255),
    project_value character varying(255),
    projection_amount double precision,
    region character varying(255),
    staff integer,
    tech_staff integer,
    create_by bigint,
    expected_stock double precision,
    project_product character varying(255),
    project_value_foreign_invest double precision,
    progress double precision,
    region_code integer
);


ALTER TABLE public.investment_project OWNER TO postgres;

--
-- Name: investment_project_finance_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_project_finance_info (
    doc_id bigint NOT NULL,
    bank_funds double precision,
    bank_remaind double precision,
    bankf_invest double precision,
    bankf_remaind double precision,
    created_at date,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    dev_funds double precision,
    dev_remaind double precision,
    foreign_invest double precision,
    foreign_remaind double precision,
    gov_credit double precision,
    gov_remaind double precision,
    own_cost double precision,
    own_remaind double precision,
    project_name character varying(255),
    id bigint NOT NULL
);


ALTER TABLE public.investment_project_finance_info OWNER TO postgres;

--
-- Name: investment_project_finance_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.investment_project_finance_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.investment_project_finance_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: investment_project_funding_source; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_project_funding_source (
    id bigint NOT NULL,
    bank_funds double precision,
    bank_reality double precision,
    bankf_invest double precision,
    bankf_reality double precision,
    created_at date,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    dev_funds double precision,
    dev_reality double precision,
    doc_id bigint,
    forecast_month character varying(255),
    foreign_invest double precision,
    foreign_reality double precision,
    gov_credit double precision,
    gov_reality double precision,
    mastery_month character varying(255),
    own_cost double precision,
    own_reality double precision,
    project_name character varying(255)
);


ALTER TABLE public.investment_project_funding_source OWNER TO postgres;

--
-- Name: investment_project_funding_source_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.investment_project_funding_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.investment_project_funding_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: investment_project_schedule_event; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_project_schedule_event (
    id bigint NOT NULL,
    april_cp double precision,
    august_cp double precision,
    contractor_name character varying(255),
    created_at date,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    december_cp double precision,
    doc_id bigint,
    duration integer,
    event_begin date,
    event_category character varying(255),
    event_cost double precision,
    event_end date,
    event_name character varying(255),
    february_cp double precision,
    january_cp double precision,
    july_cp double precision,
    june_cp double precision,
    march_cp double precision,
    may_cp double precision,
    november_cp double precision,
    october_cp double precision,
    project_name character varying(255),
    september_cp double precision
);


ALTER TABLE public.investment_project_schedule_event OWNER TO postgres;

--
-- Name: investment_project_schedule_event_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.investment_project_schedule_event ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.investment_project_schedule_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: investment_project_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_project_statuses (
    doc_id bigint NOT NULL,
    created_at date,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    deadline date,
    executed_job character varying(255),
    project_name character varying(255),
    status character varying(2000),
    updated_date date,
    id bigint NOT NULL
);


ALTER TABLE public.investment_project_statuses OWNER TO postgres;

--
-- Name: investment_project_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.investment_project_statuses ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.investment_project_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: investment_projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_projects (
    doc_id bigint NOT NULL,
    begin_date date,
    begin_end date,
    budg_revenue double precision,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    district_id character varying(255),
    district_name character varying(255),
    export double precision,
    import double precision,
    l_partner character varying(255),
    local_level character varying(255),
    lp_stir character varying(255),
    p_cost double precision,
    p_country character varying(255),
    p_currency character varying(255),
    p_initiator character varying(255),
    p_investor character varying(255),
    p_name character varying(255),
    p_scope character varying(255),
    product_type character varying(255),
    project_power character varying(255),
    project_type character varying(255),
    region_id character varying(255),
    region_name character varying(255),
    start_act character varying(255),
    start_date date,
    unit character varying(255),
    workplace integer,
    id bigint NOT NULL
);


ALTER TABLE public.investment_projects OWNER TO postgres;

--
-- Name: investment_projects_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.investment_projects ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.investment_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: investment_step; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investment_step (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name text,
    investment_project_id bigint,
    status character varying(255),
    create_by bigint,
    CONSTRAINT investment_step_status_check CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('COMPLETED'::character varying)::text, ('LATER'::character varying)::text])))
);


ALTER TABLE public.investment_step OWNER TO postgres;

--
-- Name: item_availability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.item_availability (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    available boolean,
    size integer,
    warehouse_id bigint
);


ALTER TABLE public.item_availability OWNER TO postgres;

--
-- Name: item_availability_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.item_availability ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.item_availability_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: legal_entity_debt; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.legal_entity_debt (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date character varying(255),
    nedoimka double precision,
    ns10code integer,
    ns10name character varying(255),
    ns11code integer,
    ns11name character varying(255),
    object_code character varying(255),
    object_name character varying(255),
    penya double precision,
    pereplata double precision,
    tin character varying(255),
    create_by bigint
);


ALTER TABLE public.legal_entity_debt OWNER TO postgres;

--
-- Name: legal_entity_debt_import_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.legal_entity_debt_import_progress (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    cron_type character varying(255),
    date_time timestamp(6) without time zone,
    exceptions text,
    organization_tin character varying(255),
    save_count integer,
    success boolean
);


ALTER TABLE public.legal_entity_debt_import_progress OWNER TO postgres;

--
-- Name: limit_report; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.limit_report (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    description character varying(255),
    expense double precision,
    limit_amount double precision,
    quantity double precision,
    organization_id bigint,
    c1id character varying(255)
);


ALTER TABLE public.limit_report OWNER TO postgres;

--
-- Name: limit_report_article; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.limit_report_article (
    limit_report_id bigint NOT NULL,
    article_id bigint NOT NULL
);


ALTER TABLE public.limit_report_article OWNER TO postgres;

--
-- Name: log_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.log_progress (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    action character varying(255),
    exception text,
    type character varying(255)
);


ALTER TABLE public.log_progress OWNER TO postgres;

--
-- Name: lot; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lot (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    base_price character varying(255),
    brand character varying(255),
    contract_number character varying(255),
    date timestamp(6) without time zone,
    lot integer,
    measure_unit character varying(255),
    product_group_name character varying(255),
    product_name character varying(255),
    product_type_name character varying(255),
    seller_name character varying(255),
    seller_region character varying(255),
    session integer,
    set_volume_tons character varying(255),
    sold_volume_tons character varying(255),
    sold_volume_uzs character varying(255),
    create_by bigint,
    product_main_category character varying(255)
);


ALTER TABLE public.lot OWNER TO postgres;

--
-- Name: measurement_unit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.measurement_unit (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    code character varying(255),
    measurement_name_long character varying(255),
    measurement_name_short character varying(255),
    create_by bigint
);


ALTER TABLE public.measurement_unit OWNER TO postgres;

--
-- Name: message; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.message (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    message text,
    receiver_id bigint,
    sender_id bigint,
    is_read boolean,
    path text,
    file_name character varying(255),
    warehouse_id bigint,
    create_by bigint,
    delete boolean
);


ALTER TABLE public.message OWNER TO postgres;

--
-- Name: meter_block; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_block (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.meter_block OWNER TO postgres;

--
-- Name: meter_block_kf_tr; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_block_kf_tr (
    meter_block_id bigint NOT NULL,
    kf_tr bigint
);


ALTER TABLE public.meter_block_kf_tr OWNER TO postgres;

--
-- Name: meter_block_meter_date; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_block_meter_date (
    meter_block_id bigint NOT NULL,
    meter_date date
);


ALTER TABLE public.meter_block_meter_date OWNER TO postgres;

--
-- Name: meter_block_meter_no; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_block_meter_no (
    meter_block_id bigint NOT NULL,
    meter_no character varying(255)
);


ALTER TABLE public.meter_block_meter_no OWNER TO postgres;

--
-- Name: meter_block_meter_rz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_block_meter_rz (
    meter_block_id bigint NOT NULL,
    meter_rz bigint
);


ALTER TABLE public.meter_block_meter_rz OWNER TO postgres;

--
-- Name: meter_block_meter_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_block_meter_type (
    meter_block_id bigint NOT NULL,
    meter_type character varying(255)
);


ALTER TABLE public.meter_block_meter_type OWNER TO postgres;

--
-- Name: meter_block_tarif_price; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_block_tarif_price (
    meter_block_id bigint NOT NULL,
    tarif_price double precision
);


ALTER TABLE public.meter_block_tarif_price OWNER TO postgres;

--
-- Name: mip2hududgaz_payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mip2hududgaz_payments (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    amount bigint,
    created_date character varying(255),
    operator character varying(255),
    org_bank character varying(255),
    org_customer_code character varying(255),
    org_inn character varying(255),
    org_mfo character varying(255),
    org_name text,
    org_rs character varying(255),
    purpose text,
    status_name character varying(255),
    tid character varying(255),
    transaction_time character varying(255),
    create_by bigint
);


ALTER TABLE public.mip2hududgaz_payments OWNER TO postgres;

--
-- Name: mip2import_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mip2import_progress (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    cron_name character varying(255),
    exceptions text,
    import_type character varying(255),
    organization_id character varying(255),
    save_count integer,
    update_count integer
);


ALTER TABLE public.mip2import_progress OWNER TO postgres;

--
-- Name: mixed_sold_lot_faktura_doc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mixed_sold_lot_faktura_doc (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    doverennost_id bigint,
    navoiy_azot_transfer_id bigint,
    sold_lot_id bigint
);


ALTER TABLE public.mixed_sold_lot_faktura_doc OWNER TO postgres;

--
-- Name: mixed_sold_lot_faktura_doc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.mixed_sold_lot_faktura_doc ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mixed_sold_lot_faktura_doc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mobile_version; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mobile_version (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    version character varying(255),
    create_by bigint
);


ALTER TABLE public.mobile_version OWNER TO postgres;

--
-- Name: navoiy_azot_transfer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.navoiy_azot_transfer (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    description text,
    quantity double precision,
    transport_driver_name character varying(255),
    transport_model character varying(255),
    transport_number character varying(255),
    transport_owner_pinfl character varying(255),
    doverennost_id bigint,
    from_warehouse_id bigint,
    product_id bigint,
    sold_lot_id bigint,
    farmer_district_id bigint,
    driver_phone_number character varying(255),
    local_id bigint,
    expeditor_pinfl character varying(255)
);


ALTER TABLE public.navoiy_azot_transfer OWNER TO postgres;

--
-- Name: navoiy_azot_transfer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.navoiy_azot_transfer ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.navoiy_azot_transfer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: notification; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notification (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    text character varying(255),
    user_id bigint,
    create_by bigint
);


ALTER TABLE public.notification OWNER TO postgres;

--
-- Name: operation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.operation (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    is_active boolean,
    name character varying(255),
    create_by bigint
);


ALTER TABLE public.operation OWNER TO postgres;

--
-- Name: organization; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    inn character varying(255),
    name character varying(255),
    name_in_lots character varying(255),
    type character varying(255),
    warehouse1c_id character varying(255),
    district_id bigint,
    contracts jsonb,
    create_by bigint,
    gas_customer_code character varying(255),
    sub_type character varying(255),
    ifutcode character varying(255),
    micro_macro_organization character varying(255),
    activity_type character varying(255),
    foundation_date date,
    industry_type character varying(255),
    main_product_type character varying(255),
    organization_director character varying(255),
    phone_number character varying(255),
    org_address character varying(255),
    CONSTRAINT organization_type_check CHECK (((type)::text = ANY (ARRAY[('STATE'::character varying)::text, ('PRIVATE'::character varying)::text])))
);


ALTER TABLE public.organization OWNER TO postgres;

--
-- Name: organization_1c; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_1c (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    address character varying(255),
    full_name character varying(255),
    inn character varying(255),
    last_operation_date date,
    name character varying(255),
    organization_code bigint,
    organization_id uuid,
    type character varying(255),
    create_by bigint
);


ALTER TABLE public.organization_1c OWNER TO postgres;

--
-- Name: organization_bank_account_saldos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_bank_account_saldos (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    account_name character varying(255),
    account_number character varying(255),
    date date,
    organization_id bigint,
    saldo_out bigint,
    create_by bigint
);


ALTER TABLE public.organization_bank_account_saldos OWNER TO postgres;

--
-- Name: organization_bank_account_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_bank_account_transactions (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    amount bigint,
    currency_code character varying(255),
    date character varying(255),
    date_execute character varying(255),
    doc_id character varying(255),
    lead_id bigint,
    purpose text,
    rcvr_account character varying(255),
    rcvr_bank character varying(255),
    rcvr_inn character varying(255),
    rcvr_mfo character varying(255),
    rcvr_name text,
    rcvr_pinfl character varying(255),
    sndr_account character varying(255),
    sndr_bank character varying(255),
    sndr_inn character varying(255),
    sndr_mfo character varying(255),
    sndr_name text,
    sndr_pinfl character varying(255),
    state_id integer,
    transaction_type character varying(255),
    account_number character varying(255),
    organization_id bigint,
    date_as_date date,
    create_by bigint
);


ALTER TABLE public.organization_bank_account_transactions OWNER TO postgres;

--
-- Name: organization_bank_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_bank_accounts (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    account_name character varying(255),
    account_number character varying(255),
    included_in_saldo_calculation boolean,
    organization_id bigint,
    create_by bigint
);


ALTER TABLE public.organization_bank_accounts OWNER TO postgres;

--
-- Name: organization_meters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_meters (
    id bigint NOT NULL,
    meter_no character varying(255) NOT NULL,
    organization_id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    meter_brand character varying(255),
    meter_location character varying(255),
    meter_service_organization character varying(255),
    organization_name character varying(255),
    which_organization character varying(255)
);


ALTER TABLE public.organization_meters OWNER TO postgres;

--
-- Name: organization_meters_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.organization_meters ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.organization_meters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: organization_partner; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_partner (
    organization_id bigint NOT NULL,
    partner_organization_id bigint NOT NULL
);


ALTER TABLE public.organization_partner OWNER TO postgres;

--
-- Name: other_docs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.other_docs (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date_doc jsonb,
    doc_type jsonb,
    num_doc jsonb,
    period jsonb,
    state jsonb,
    summ_doc jsonb
);


ALTER TABLE public.other_docs OWNER TO postgres;

--
-- Name: payment_block; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payment_block (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.payment_block OWNER TO postgres;

--
-- Name: payment_block_pay_date; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payment_block_pay_date (
    payment_block_id bigint NOT NULL,
    pay_date date
);


ALTER TABLE public.payment_block_pay_date OWNER TO postgres;

--
-- Name: payment_block_pay_sum; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payment_block_pay_sum (
    payment_block_id bigint NOT NULL,
    pay_sum bigint
);


ALTER TABLE public.payment_block_pay_sum OWNER TO postgres;

--
-- Name: payment_block_pay_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payment_block_pay_type (
    payment_block_id bigint NOT NULL,
    pay_type character varying(255)
);


ALTER TABLE public.payment_block_pay_type OWNER TO postgres;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    pay_date jsonb,
    pay_sum jsonb,
    pay_type jsonb
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: personal; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal (
    id bigint NOT NULL,
    academic_degree character varying(255),
    academic_title character varying(255),
    awards character varying(255),
    birth_date character varying(255),
    country character varying(255),
    deputy_status character varying(255),
    disability character varying(255),
    document character varying(255),
    education character varying(255),
    employee_number character varying(255),
    expiry_date character varying(255),
    first_name character varying(255),
    foreign_languages character varying(255),
    gender character varying(255),
    home_phone character varying(255),
    img character varying(255),
    inps character varying(255),
    internal_phone character varying(255),
    issue_date character varying(255),
    issued_by character varying(255),
    job_grade character varying(255),
    last_name character varying(255),
    middle_name character varying(255),
    military_rank character varying(255),
    military_service_status character varying(255),
    mobile_phone character varying(255),
    nationality character varying(255),
    organization_name character varying(255),
    organization_stir character varying(255),
    passport_series_number character varying(255),
    permanent_address character varying(255),
    pinfl character varying(255),
    place_of_birth character varying(255),
    political_affiliation character varying(255),
    "position" character varying(255),
    position_count integer,
    registration_date character varying(255),
    specialization character varying(255),
    stir character varying(255),
    work_phone character varying(255),
    district_id bigint,
    region_id bigint,
    education_level character varying(255),
    end_date date,
    start_date date,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    military_ticket_number character varying(255),
    position_id bigint,
    department_id bigint,
    status character varying(255)
);


ALTER TABLE public.personal OWNER TO postgres;

--
-- Name: personal_awards; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_awards (
    personal_id bigint NOT NULL,
    awards character varying(255)
);


ALTER TABLE public.personal_awards OWNER TO postgres;

--
-- Name: personal_check; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_check (
    id bigint NOT NULL,
    birth_date character varying(255),
    created_at timestamp(6) without time zone,
    department_id character varying(255),
    department_name character varying(255),
    end_date date,
    first_name character varying(255),
    gender character varying(255),
    last_name character varying(255),
    middle_name character varying(255),
    nationality character varying(255),
    one_cid character varying(255),
    organization_id bigint,
    parent_department_id character varying(255),
    parent_department_name character varying(255),
    passport_series_number character varying(255),
    pinfl character varying(255),
    start_date date,
    updated_at timestamp(6) without time zone,
    academic_degree character varying(255),
    awards character varying(255),
    country character varying(255),
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    deputy_status character varying(255),
    district character varying(255),
    employee_number character varying(255),
    foreign_languages character varying(255),
    home_phone character varying(255),
    military_service_status character varying(255),
    military_ticket_number character varying(255),
    phone_number character varying(255),
    place_of_birth character varying(255),
    "position" character varying(255),
    region character varying(255),
    status character varying(255)
);


ALTER TABLE public.personal_check OWNER TO postgres;

--
-- Name: personal_check_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.personal_check ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.personal_check_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: personal_departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_departments (
    personal_id bigint NOT NULL,
    departments_id bigint NOT NULL
);


ALTER TABLE public.personal_departments OWNER TO postgres;

--
-- Name: personal_foreign_languages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_foreign_languages (
    personal_id bigint NOT NULL,
    foreign_languages character varying(255)
);


ALTER TABLE public.personal_foreign_languages OWNER TO postgres;

--
-- Name: personal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.personal ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.personal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: personal_job_names; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_job_names (
    personal_id bigint NOT NULL,
    job_names character varying(255)
);


ALTER TABLE public.personal_job_names OWNER TO postgres;

--
-- Name: personal_relative; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_relative (
    relative_id bigint NOT NULL,
    personal_id bigint NOT NULL
);


ALTER TABLE public.personal_relative OWNER TO postgres;

--
-- Name: personal_salary; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_salary (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    month_of_salary integer,
    phone_number character varying(255),
    pinfl character varying(255) NOT NULL,
    salary_given_date date,
    text text,
    year_of_salary integer,
    personal_id bigint
);


ALTER TABLE public.personal_salary OWNER TO postgres;

--
-- Name: personal_salary_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.personal_salary ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.personal_salary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: plan; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plan (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    approved boolean DEFAULT false,
    approved_by bigint,
    deleted boolean DEFAULT false,
    deleted_by bigint,
    main_plan boolean NOT NULL,
    organization_id bigint,
    parent_plan_id bigint,
    product_id bigint,
    purpose character varying(255),
    type character varying(255),
    year integer,
    create_by bigint,
    CONSTRAINT plan_type_check CHECK (((type)::text = ANY (ARRAY[('PRODUCTION'::character varying)::text, ('EXPENSE'::character varying)::text])))
);


ALTER TABLE public.plan OWNER TO postgres;

--
-- Name: plan_monthly_values; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plan_monthly_values (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    month smallint,
    value double precision,
    plan_id bigint NOT NULL,
    create_by bigint,
    CONSTRAINT plan_monthly_values_month_check CHECK (((month >= 0) AND (month <= 11)))
);


ALTER TABLE public.plan_monthly_values OWNER TO postgres;

--
-- Name: position; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."position" (
    id bigint NOT NULL,
    name character varying(255)
);


ALTER TABLE public."position" OWNER TO postgres;

--
-- Name: position_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."position" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.position_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: product; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    mxik_code character varying(255),
    mxik_name character varying(255),
    type character varying(255),
    measure_code character varying(255),
    measure_unit character varying(255),
    create_by bigint
);


ALTER TABLE public.product OWNER TO postgres;

--
-- Name: product_code; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_code (
    mxik_code text,
    group_name text,
    class_name text,
    position_name text,
    sub_name text,
    brand_name text,
    attribute_name text,
    mxik_name text,
    barcode text,
    attached_measurement_group text,
    attached_unit_of_measurement text,
    attached_pack text,
    recommended_measurement_group text,
    recommended_unit_of_measurement text,
    privilege_id text,
    x text,
    y text
);


ALTER TABLE public.product_code OWNER TO postgres;

--
-- Name: product_mxik; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_mxik (
    id text,
    name text
);


ALTER TABLE public.product_mxik OWNER TO postgres;

--
-- Name: product_tiftn_code; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_tiftn_code (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone DEFAULT now() NOT NULL,
    datetime_updated timestamp(6) without time zone DEFAULT now() NOT NULL,
    code character varying(255),
    name character varying(255),
    create_by bigint,
    status text DEFAULT 'BOSHQALAR'::text
);


ALTER TABLE public.product_tiftn_code OWNER TO postgres;

--
-- Name: product_workshop_plan; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_workshop_plan (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    end_date date,
    start_date date,
    product_id bigint,
    workshop_id bigint
);


ALTER TABLE public.product_workshop_plan OWNER TO postgres;

--
-- Name: profit_loss_1c; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profit_loss_1c (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    organization_id bigint,
    profit_loss bigint,
    create_by bigint
);


ALTER TABLE public.profit_loss_1c OWNER TO postgres;

--
-- Name: projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    current_year double precision,
    growth_percent double precision,
    next_year double precision,
    projects_count double precision,
    all_investment_id bigint
);


ALTER TABLE public.projects OWNER TO postgres;

--
-- Name: queue_code; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.queue_code (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    code integer,
    is_expired boolean,
    pair boolean,
    warehouse_id bigint
);


ALTER TABLE public.queue_code OWNER TO postgres;

--
-- Name: queue_code_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.queue_code ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.queue_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: reading_block; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reading_block (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.reading_block OWNER TO postgres;

--
-- Name: reading_block_meter_no; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reading_block_meter_no (
    reading_block_id bigint NOT NULL,
    meter_no character varying(255)
);


ALTER TABLE public.reading_block_meter_no OWNER TO postgres;

--
-- Name: reading_block_meter_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reading_block_meter_type (
    reading_block_id bigint NOT NULL,
    meter_type character varying(255)
);


ALTER TABLE public.reading_block_meter_type OWNER TO postgres;

--
-- Name: reading_block_reading; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reading_block_reading (
    reading_block_id bigint NOT NULL,
    reading bigint
);


ALTER TABLE public.reading_block_reading OWNER TO postgres;

--
-- Name: reading_block_reading_date; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reading_block_reading_date (
    reading_block_id bigint NOT NULL,
    reading_date date
);


ALTER TABLE public.reading_block_reading_date OWNER TO postgres;

--
-- Name: readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.readings (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    meter_no jsonb,
    meter_type jsonb,
    reading jsonb,
    reading_date jsonb
);


ALTER TABLE public.readings OWNER TO postgres;

--
-- Name: region; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.region (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255),
    faktura_region_code bigint,
    faktura_region_id bigint,
    name_uz character varying(255),
    faktura_region_name character varying(255),
    create_by bigint
);


ALTER TABLE public.region OWNER TO postgres;

--
-- Name: relatives; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relatives (
    id bigint NOT NULL,
    birth_date date,
    document character varying(255),
    expiration_date date,
    first_name character varying(255),
    gender character varying(255),
    issue_date date,
    issued_by character varying(255),
    jshshir character varying(255),
    kinship character varying(255),
    last_name character varying(255),
    middle_name character varying(255),
    passport_number character varying(255),
    district_id bigint,
    personal_id bigint,
    region_id bigint,
    is_deleted boolean DEFAULT false,
    CONSTRAINT relatives_kinship_check CHECK (((kinship)::text = ANY (ARRAY[('OTA'::character varying)::text, ('ONA'::character varying)::text, ('OZI'::character varying)::text, ('ER'::character varying)::text, ('XOTIN'::character varying)::text, ('FARZAND'::character varying)::text, ('AYOL'::character varying)::text, ('QAYNOTA'::character varying)::text, ('QAYNONA'::character varying)::text, ('QAYN_AKA_UKA'::character varying)::text, ('AKA_UKA'::character varying)::text, ('QAYN_OPA_SINGIL'::character varying)::text, ('OPA_SINGIL'::character varying)::text])))
);


ALTER TABLE public.relatives OWNER TO postgres;

--
-- Name: relatives_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.relatives ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.relatives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: report_document; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.report_document (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone DEFAULT now() NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    account character varying(255),
    amount double precision,
    approver character varying(255),
    basis character varying(255),
    contract_amount numeric(38,2),
    contractor character varying(255),
    contractor_agreement character varying(255),
    created_at timestamp(6) without time zone,
    currency character varying(255),
    date timestamp(6) without time zone,
    document_number character varying(255),
    expense_direction character varying(255),
    initiator character varying(255),
    inn character varying(255),
    number character varying(255),
    operation_type character varying(255),
    payment_purpose character varying(255),
    priority character varying(255),
    recipient character varying(255),
    responsible character varying(255),
    status character varying(255),
    status_code integer,
    c1id character varying(255),
    article1cid character varying(255)
);


ALTER TABLE public.report_document OWNER TO postgres;

--
-- Name: report_document_article_id; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.report_document_article_id (
    report_document_id bigint NOT NULL,
    article_id_id bigint NOT NULL
);


ALTER TABLE public.report_document_article_id OWNER TO postgres;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(50)
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: saldo_period; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saldo_period (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    credit jsonb,
    debit jsonb,
    period jsonb,
    redebit jsonb,
    saldo_in jsonb,
    saldo_out jsonb
);


ALTER TABLE public.saldo_period OWNER TO postgres;

--
-- Name: saldo_period_credit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saldo_period_credit (
    saldo_period_id bigint NOT NULL,
    credit double precision
);


ALTER TABLE public.saldo_period_credit OWNER TO postgres;

--
-- Name: saldo_period_debit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saldo_period_debit (
    saldo_period_id bigint NOT NULL,
    debit double precision
);


ALTER TABLE public.saldo_period_debit OWNER TO postgres;

--
-- Name: saldo_period_period; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saldo_period_period (
    saldo_period_id bigint NOT NULL,
    period date
);


ALTER TABLE public.saldo_period_period OWNER TO postgres;

--
-- Name: saldo_period_saldo_in; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saldo_period_saldo_in (
    saldo_period_id bigint NOT NULL,
    saldo_in double precision
);


ALTER TABLE public.saldo_period_saldo_in OWNER TO postgres;

--
-- Name: saldo_period_saldo_out; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saldo_period_saldo_out (
    saldo_period_id bigint NOT NULL,
    saldo_out double precision
);


ALTER TABLE public.saldo_period_saldo_out OWNER TO postgres;

--
-- Name: scale; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scale (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255)
);


ALTER TABLE public.scale OWNER TO postgres;

--
-- Name: scale_attach; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scale_attach (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    cloud_path text,
    content_type character varying(255),
    origin_name text,
    size bigint,
    type character varying(255),
    weight_id bigint,
    local_id bigint,
    create_by bigint
);


ALTER TABLE public.scale_attach OWNER TO postgres;

--
-- Name: scale_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.scale ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.scale_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: shlagbaun; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shlagbaun (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    number integer,
    status boolean,
    success boolean,
    comment character varying(255)
);


ALTER TABLE public.shlagbaun OWNER TO postgres;

--
-- Name: shlagbaun_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.shlagbaun ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.shlagbaun_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sold_lot; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sold_lot (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    account character varying(255),
    bank_name character varying(255),
    bargain_status character varying(255),
    buyer_address character varying(255),
    buyer_inn character varying(255),
    buyer_name character varying(255),
    contract_name character varying(255),
    contract_number character varying(255),
    contract_type integer,
    currency character varying(255),
    damount character varying(255),
    delivery_date date,
    delivery_date_deadline integer,
    lot_id bigint,
    measure_unit character varying(255),
    mfo character varying(255),
    pay_date date,
    payment_date_deadline integer,
    price_per_contract double precision,
    product_group character varying(255),
    product_name character varying(255),
    quantity integer,
    quantity_in_lot integer,
    seller_address character varying(255),
    seller_inn character varying(255),
    seller_name character varying(255),
    session integer,
    start_price double precision,
    transaction_date timestamp(6) without time zone,
    transaction_number character varying(255),
    transaction_sum double precision,
    warehouse character varying(255),
    product_group_name character varying(255),
    transaction_date_as_date date,
    real_quantity double precision,
    mxik_code character varying(255),
    transaction_sum_calculated double precision,
    real_quantity_for_amount double precision,
    converted_measure_unit character varying(255),
    product_main_category character varying(255),
    create_by bigint,
    mxik_name character varying(255),
    buyer_phone character varying(255),
    seller_phone character varying(255)
);


ALTER TABLE public.sold_lot OWNER TO postgres;

--
-- Name: sold_lot_1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sold_lot_1 (
    transnumber integer,
    transdate text,
    contractnumber integer,
    productgroup text,
    productname text,
    startprice numeric,
    pricepercontract numeric,
    transsum numeric,
    quantityinlot integer,
    quantity integer,
    unitofmeasure text,
    sellerinn integer,
    sellername text,
    selleradress text,
    buyerinn integer,
    buyername text,
    buyeradress text,
    contractname text,
    contracttype integer,
    bargainstatus text,
    "PaymentDate" integer,
    "DeliveryDate" integer,
    "DAmount" integer,
    "Comment" text,
    "FineDeal" text,
    "FineDate" text,
    "Code" text,
    warehouse text,
    paydate text,
    delivdate text,
    valuta text,
    "Account" text,
    bankname text,
    "Mfo" integer,
    "Session" integer
);


ALTER TABLE public.sold_lot_1 OWNER TO postgres;

--
-- Name: staff_and_technics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.staff_and_technics (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    project_id bigint,
    date date
);


ALTER TABLE public.staff_and_technics OWNER TO postgres;

--
-- Name: staff_position; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.staff_position (
    id bigint NOT NULL,
    organization_stir character varying(255),
    personal_count integer,
    position_name character varying(255),
    department_id bigint,
    personal_limit integer
);


ALTER TABLE public.staff_position OWNER TO postgres;

--
-- Name: staff_position_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.staff_position ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staff_position_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staff_position_personal; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.staff_position_personal (
    staff_position_id bigint NOT NULL,
    personal_id bigint NOT NULL
);


ALTER TABLE public.staff_position_personal OWNER TO postgres;

--
-- Name: stock_income_output_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stock_income_output_detail (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    account character varying(255),
    account_credit character varying(255),
    account_debit character varying(255),
    datetime_deleted timestamp(6) without time zone,
    deleted boolean,
    stock double precision,
    sub1 character varying(255),
    sub2 character varying(255),
    type character varying(255),
    warehouse_stock_income_output_id bigint,
    operation_type character varying(255),
    operation_type_code character varying(255),
    sub1id character varying(255),
    sub2id character varying(255),
    create_by bigint,
    wagon_number character varying(255),
    CONSTRAINT stock_income_output_detail_type_check CHECK (((type)::text = ANY (ARRAY[('INCOME'::character varying)::text, ('OUTCOME'::character varying)::text])))
);


ALTER TABLE public.stock_income_output_detail OWNER TO postgres;

--
-- Name: table_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.table_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.table_seq OWNER TO postgres;

--
-- Name: technic; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.technic (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    count integer,
    date date,
    type character varying(255),
    staff_technic_id bigint,
    type_id bigint
);


ALTER TABLE public.technic OWNER TO postgres;

--
-- Name: technic_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.technic_type (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255)
);


ALTER TABLE public.technic_type OWNER TO postgres;

--
-- Name: trade_offers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trade_offers (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    contract_id character varying(255),
    contract_lot bigint,
    currency character varying(255),
    deal_lot_count integer,
    exchange_rate double precision,
    offer_direction character varying(255),
    offer_lot_count integer,
    offer_price double precision,
    offer_status character varying(255),
    product_unit character varying(255),
    region_code character varying(255),
    rn bigint,
    seller_tin character varying(255),
    session character varying(255),
    short_name character varying(255),
    total_count bigint,
    trade_date date,
    deal_number character varying(255)
);


ALTER TABLE public.trade_offers OWNER TO postgres;

--
-- Name: transfer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transfer (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    approved_date timestamp(6) without time zone,
    status character varying(255),
    total_quantity double precision,
    transfer_status character varying(255),
    approved_user_id bigint,
    from_warehouse_id bigint,
    to_warehouse_id bigint,
    warehouse_stock_income_output_id bigint,
    organization_id bigint,
    period date,
    product_id character varying(255),
    product_name character varying(255),
    lot_id bigint,
    doverennost_number character varying(255),
    doverennost_id bigint,
    signature text,
    product_name_in_lot character varying(255),
    driver_pinfl character varying(255),
    transport_number character varying(255),
    transport_model character varying(255),
    deliverer_pinfl character varying(255),
    description text,
    mxik_code character varying(255),
    product_mxik_id bigint,
    farmer_district_id bigint,
    warehouse_district_id bigint,
    transport_owner_pinfl character varying(255),
    driver_name character varying(255),
    factory_id bigint,
    create_by bigint,
    e_nakladnoy_number character varying(255),
    wagon_number character varying(255),
    cancelled_by_user_id bigint,
    CONSTRAINT transfer_status_check CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('DELETE'::character varying)::text, ('NO_VALID'::character varying)::text, ('TEMP'::character varying)::text, ('DIS_ACTIVE'::character varying)::text, ('CANCELLED'::character varying)::text]))),
    CONSTRAINT transfer_transfer_status_check CHECK (((transfer_status)::text = ANY (ARRAY[('NEW'::character varying)::text, ('ON_THE_ROAD'::character varying)::text, ('DELIVERED'::character varying)::text])))
);


ALTER TABLE public.transfer OWNER TO postgres;

--
-- Name: transfer_status_change; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transfer_status_change (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    status character varying(255),
    transfer_id bigint
);


ALTER TABLE public.transfer_status_change OWNER TO postgres;

--
-- Name: transfer_status_change_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.transfer_status_change ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.transfer_status_change_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: transfer_x_warehouse_test; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transfer_x_warehouse_test (
    id bigint,
    from_warehouse_id bigint,
    to_warehouse_id bigint
);


ALTER TABLE public.transfer_x_warehouse_test OWNER TO postgres;

--
-- Name: transgaz_organization; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transgaz_organization (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    organization_name character varying(255),
    point_code character varying(255)
);


ALTER TABLE public.transgaz_organization OWNER TO postgres;

--
-- Name: transgaz_point; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transgaz_point (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    device_model character varying(255),
    device_serial_number character varying(255),
    grs_name character varying(255),
    modem character varying(255),
    org_type character varying(255),
    point_code character varying(255),
    point_id character varying(255),
    point_type character varying(255),
    purpose character varying,
    create_by bigint
);


ALTER TABLE public.transgaz_point OWNER TO postgres;

--
-- Name: transgaz_point_readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transgaz_point_readings (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    co2 double precision,
    n2 double precision,
    accounting_time integer,
    density double precision,
    differential_pressure double precision,
    point_id character varying(255),
    pressure double precision,
    temperature double precision,
    "timestamp" timestamp(6) without time zone,
    volume double precision,
    create_by bigint
);


ALTER TABLE public.transgaz_point_readings OWNER TO postgres;

--
-- Name: ttn; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ttn (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    message character varying(255),
    name character varying(255),
    result_code integer NOT NULL,
    unique_id character varying(255),
    transfer_id bigint,
    status character varying(255),
    description text,
    create_by bigint,
    is_sent boolean
);


ALTER TABLE public.ttn OWNER TO postgres;

--
-- Name: user_1c_organization; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_1c_organization (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    organization_id bigint,
    user_id bigint,
    create_by bigint
);


ALTER TABLE public.user_1c_organization OWNER TO postgres;

--
-- Name: user_ability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_ability (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255),
    CONSTRAINT user_ability_name_check CHECK (((name)::text = ANY (ARRAY[('LOTLAR_MONITORING'::character varying)::text, ('DEBITOR_KREDITOR'::character varying)::text, ('BANK_AYLANMALARI'::character varying)::text, ('OMBOR_MONITORING'::character varying)::text, ('XOMASHYO_SARFI'::character varying)::text, ('EKIN_EKILISHI'::character varying)::text, ('OGIT_TALAB'::character varying)::text, ('IMPORT_EXPORT'::character varying)::text, ('INVESTITSIYA_MONITORING'::character varying)::text, ('MOLIYAVIY_MODEL'::character varying)::text, ('NARXLARNI_ORGANISH'::character varying)::text, ('TAYYOR_MAHSULOTLAR'::character varying)::text, ('E_NAKLADNOY'::character varying)::text])))
);


ALTER TABLE public.user_ability OWNER TO postgres;

--
-- Name: user_action_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_action_log (
    id bigint NOT NULL,
    action_info character varying(255),
    requested_url character varying(255),
    "time" timestamp(6) without time zone NOT NULL,
    user_id bigint
);


ALTER TABLE public.user_action_log OWNER TO postgres;

--
-- Name: user_action_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.user_action_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.user_action_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_roles (
    user_id bigint NOT NULL,
    role_id integer NOT NULL
);


ALTER TABLE public.user_roles OWNER TO postgres;

--
-- Name: user_user_ability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_user_ability (
    user_ability_id bigint NOT NULL,
    user_id bigint NOT NULL
);


ALTER TABLE public.user_user_ability OWNER TO postgres;

--
-- Name: user_warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_warehouse (
    username character varying,
    warehouse1cid character varying
);


ALTER TABLE public.user_warehouse OWNER TO postgres;

--
-- Name: user_warehouse1cid; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_warehouse1cid (
    id integer,
    username text,
    warehouse1cid text
);


ALTER TABLE public.user_warehouse1cid OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    deleted boolean DEFAULT false,
    full_name character varying(255),
    is_enabled boolean DEFAULT true,
    password character varying(255),
    picture character varying(255),
    username character varying(255) NOT NULL,
    organization_id bigint,
    warehouse_id bigint,
    passport_number character varying(255),
    pinfl character varying(255),
    create_by bigint
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: wagon_numbers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wagon_numbers (
    shipment_id bigint NOT NULL,
    wagon_number character varying(255),
    product_etsng_code character varying(255),
    product_etsng_name character varying(255),
    product_gng_code character varying(255),
    product_gng_name character varying(255),
    weight_netto double precision,
    id bigint NOT NULL
);


ALTER TABLE public.wagon_numbers OWNER TO postgres;

--
-- Name: wagon_numbers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.wagon_numbers ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.wagon_numbers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    name character varying(255),
    warehouse1cid character varying(255),
    address character varying(255),
    created_by_id bigint,
    district_id bigint,
    organization_id bigint,
    warehouse_type character varying(255),
    create_by bigint,
    latitude double precision,
    longitude double precision,
    CONSTRAINT warehouse_warehouse_type_check CHECK (((warehouse_type)::text = ANY (ARRAY[('CLIENT'::character varying)::text, ('STORAGE'::character varying)::text, ('PRODUCTION'::character varying)::text])))
);


ALTER TABLE public.warehouse OWNER TO postgres;

--
-- Name: warehouse_2; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse_2 (
    id bigint,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    name character varying(255),
    warehouse1cid character varying(255),
    address character varying(255),
    created_by_id bigint,
    district_id bigint,
    organization_id bigint,
    warehouse_type character varying(255),
    create_by bigint,
    latitude double precision,
    longitude double precision
);


ALTER TABLE public.warehouse_2 OWNER TO postgres;

--
-- Name: warehouse_amount_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.warehouse_amount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.warehouse_amount_id_seq OWNER TO postgres;

--
-- Name: warehouse_amount; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse_amount (
    id bigint DEFAULT nextval('public.warehouse_amount_id_seq'::regclass) NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date date,
    quantity double precision,
    organization_id bigint,
    product_id bigint,
    warehouse_id bigint,
    create_by bigint
);


ALTER TABLE public.warehouse_amount OWNER TO postgres;

--
-- Name: warehouse_balance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.warehouse_balance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.warehouse_balance_id_seq OWNER TO postgres;

--
-- Name: warehouse_balance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse_balance (
    id bigint DEFAULT nextval('public.warehouse_balance_id_seq'::regclass) NOT NULL,
    datetime_created timestamp(6) without time zone,
    datetime_updated timestamp(6) without time zone,
    date date,
    quantity double precision,
    organization_id bigint,
    product_id character varying(255),
    warehouse_id bigint,
    product_name character varying(255),
    create_by bigint
);


ALTER TABLE public.warehouse_balance OWNER TO postgres;

--
-- Name: warehouse_stock; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse_stock (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    date date,
    organization_id character varying(255),
    product_code character varying(255),
    quantity double precision,
    stock_date date,
    unit character varying(255),
    warehouse_id character varying(255),
    product_name character varying(255),
    approved_date timestamp(6) without time zone,
    is_approved boolean DEFAULT false,
    approved_by_user_id bigint,
    approved_quantity double precision,
    create_by bigint
);


ALTER TABLE public.warehouse_stock OWNER TO postgres;

--
-- Name: warehouse_stock_income_output; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse_stock_income_output (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    account character varying(255),
    closing_stock double precision,
    datetime_deleted timestamp(6) without time zone,
    deleted boolean,
    inn character varying(255),
    mxik_code character varying(255),
    opening_stock integer,
    organization_id character varying(255),
    period timestamp(6) without time zone,
    product_id character varying(255),
    product_name character varying(255),
    warehouse_id character varying(255),
    warehouse_name character varying(255),
    unit character varying(255),
    create_by bigint
);


ALTER TABLE public.warehouse_stock_income_output OWNER TO postgres;

--
-- Name: water_consumption; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.water_consumption (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    all_used integer,
    comp_account character varying(255),
    comp_address character varying(255),
    comp_name character varying(255),
    comp_tin character varying(255),
    data_id integer,
    debt double precision,
    district_id character varying(255),
    district_name character varying(255),
    end_debt double precision,
    end_entitle double precision,
    entitlement double precision,
    filial_code character varying(255),
    filial_name character varying(255),
    for_month integer,
    month integer,
    monthly_estimate double precision,
    monthly_paid double precision,
    organization_id bigint,
    region_id character varying(255),
    region_name character varying(255),
    remainder integer,
    send_datetime character varying(255),
    year integer
);


ALTER TABLE public.water_consumption OWNER TO postgres;

--
-- Name: weight; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.weight (
    id bigint NOT NULL,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    brutto double precision,
    local_id bigint,
    netto double precision,
    scale_id bigint,
    tara double precision
);


ALTER TABLE public.weight OWNER TO postgres;

--
-- Name: weight_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.weight ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.weight_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workshop; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workshop (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    code character varying(255),
    name character varying(255)
);


ALTER TABLE public.workshop OWNER TO postgres;

--
-- Name: workshop_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workshop_assignment (
    id bigint NOT NULL,
    create_by bigint,
    datetime_created timestamp(6) without time zone NOT NULL,
    datetime_updated timestamp(6) without time zone NOT NULL,
    end_date date,
    role character varying(255),
    start_date date,
    user_id bigint NOT NULL,
    workshop_id bigint NOT NULL,
    CONSTRAINT workshop_assignment_role_check CHECK (((role)::text = ANY (ARRAY[('MANAGER'::character varying)::text, ('WORKER'::character varying)::text, ('CONTROLLER'::character varying)::text, ('OPERATOR'::character varying)::text])))
);


ALTER TABLE public.workshop_assignment OWNER TO postgres;

--
-- Name: agro_fertilizer_demand agro_fertilizer_demand_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.agro_fertilizer_demand
    ADD CONSTRAINT agro_fertilizer_demand_pkey PRIMARY KEY (id);


--
-- Name: all_investment all_investment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.all_investment
    ADD CONSTRAINT all_investment_pkey PRIMARY KEY (id);


--
-- Name: application_divorce application_divorce_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.application_divorce
    ADD CONSTRAINT application_divorce_pkey PRIMARY KEY (id);


--
-- Name: application application_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (id);


--
-- Name: argus argus_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.argus
    ADD CONSTRAINT argus_pkey PRIMARY KEY (id);


--
-- Name: article article_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article
    ADD CONSTRAINT article_pkey PRIMARY KEY (id);


--
-- Name: attachment attachment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT attachment_pkey PRIMARY KEY (id);


--
-- Name: birja_lot_import_progress birja_lot_import_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.birja_lot_import_progress
    ADD CONSTRAINT birja_lot_import_progress_pkey PRIMARY KEY (id);


--
-- Name: article c1id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article
    ADD CONSTRAINT c1id UNIQUE (c1id);


--
-- Name: camera camera_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camera
    ADD CONSTRAINT camera_pkey PRIMARY KEY (id);


--
-- Name: car car_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.car
    ADD CONSTRAINT car_pkey PRIMARY KEY (id);


--
-- Name: carrier carrier_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carrier
    ADD CONSTRAINT carrier_pkey PRIMARY KEY (id);


--
-- Name: check_status check_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.check_status
    ADD CONSTRAINT check_status_pkey PRIMARY KEY (id);


--
-- Name: connection_status connection_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connection_status
    ADD CONSTRAINT connection_status_pkey PRIMARY KEY (id);


--
-- Name: contr_agent contr_agent_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contr_agent
    ADD CONSTRAINT contr_agent_pkey PRIMARY KEY (id);


--
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (id);


--
-- Name: country_code country_code_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country_code
    ADD CONSTRAINT country_code_pkey PRIMARY KEY (id);


--
-- Name: court_case court_case_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.court_case
    ADD CONSTRAINT court_case_pkey PRIMARY KEY (id);


--
-- Name: cron_status cron_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cron_status
    ADD CONSTRAINT cron_status_pkey PRIMARY KEY (id);


--
-- Name: crop_and_sold_lot_dto crop_and_sold_lot_dto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crop_and_sold_lot_dto
    ADD CONSTRAINT crop_and_sold_lot_dto_pkey PRIMARY KEY (id);


--
-- Name: crop_and_sold_lotdto crop_and_sold_lotdto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crop_and_sold_lotdto
    ADD CONSTRAINT crop_and_sold_lotdto_pkey PRIMARY KEY (id);


--
-- Name: crop crop_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crop
    ADD CONSTRAINT crop_pkey PRIMARY KEY (id);


--
-- Name: daily_birja_selling daily_birja_selling_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_birja_selling
    ADD CONSTRAINT daily_birja_selling_pkey PRIMARY KEY (id);


--
-- Name: debtor_creditor1c debtor_creditor1c_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.debtor_creditor1c
    ADD CONSTRAINT debtor_creditor1c_pkey PRIMARY KEY (id);


--
-- Name: debtor_creditor1cimport_progress debtor_creditor1cimport_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.debtor_creditor1cimport_progress
    ADD CONSTRAINT debtor_creditor1cimport_progress_pkey PRIMARY KEY (id);


--
-- Name: deliver deliver_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deliver
    ADD CONSTRAINT deliver_pkey PRIMARY KEY (id);


--
-- Name: department department_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT department_pkey PRIMARY KEY (id);


--
-- Name: department_types department_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_types
    ADD CONSTRAINT department_types_pkey PRIMARY KEY (id);


--
-- Name: district district_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.district
    ADD CONSTRAINT district_pkey PRIMARY KEY (id);


--
-- Name: doverennost_file doverennost_file_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doverennost_file
    ADD CONSTRAINT doverennost_file_pkey PRIMARY KEY (id);


--
-- Name: driver driver_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver
    ADD CONSTRAINT driver_pkey PRIMARY KEY (id);


--
-- Name: drivers_info drivers_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers_info
    ADD CONSTRAINT drivers_info_pkey PRIMARY KEY (id);


--
-- Name: eimzo eimzo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eimzo
    ADD CONSTRAINT eimzo_pkey PRIMARY KEY (id);


--
-- Name: electric_meters electric_meters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electric_meters
    ADD CONSTRAINT electric_meters_pkey PRIMARY KEY (id);


--
-- Name: electricity_legal_entity electricity_legal_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT electricity_legal_entity_pkey PRIMARY KEY (id);


--
-- Name: employee employee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (id);


--
-- Name: employee_type employee_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_type
    ADD CONSTRAINT employee_type_pkey PRIMARY KEY (id);


--
-- Name: enakladnoy_shipment_status enakladnoy_shipment_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enakladnoy_shipment_status
    ADD CONSTRAINT enakladnoy_shipment_status_pkey PRIMARY KEY (id);


--
-- Name: enaklodnoy enaklodnoy_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enaklodnoy
    ADD CONSTRAINT enaklodnoy_pkey PRIMARY KEY (id);


--
-- Name: enaklodnoy_shipment enaklodnoy_shipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enaklodnoy_shipment
    ADD CONSTRAINT enaklodnoy_shipment_pkey PRIMARY KEY (id);


--
-- Name: enaklodnoy_wagon enaklodnoy_wagon_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enaklodnoy_wagon
    ADD CONSTRAINT enaklodnoy_wagon_pkey PRIMARY KEY (id);


--
-- Name: export_applications export_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.export_applications
    ADD CONSTRAINT export_applications_pkey PRIMARY KEY (id);


--
-- Name: export_data export_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.export_data
    ADD CONSTRAINT export_data_pkey PRIMARY KEY (id);


--
-- Name: faktura_uz_document_content faktura_uz_document_content_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faktura_uz_document_content
    ADD CONSTRAINT faktura_uz_document_content_pkey PRIMARY KEY (id);


--
-- Name: faktura_uz_document_content_product faktura_uz_document_content_product_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faktura_uz_document_content_product
    ADD CONSTRAINT faktura_uz_document_content_product_pkey PRIMARY KEY (id);


--
-- Name: faktura_uz_document faktura_uz_document_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faktura_uz_document
    ADD CONSTRAINT faktura_uz_document_pkey PRIMARY KEY (id);


--
-- Name: faktura_uz_documnet_status faktura_uz_documnet_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faktura_uz_documnet_status
    ADD CONSTRAINT faktura_uz_documnet_status_pkey PRIMARY KEY (id);


--
-- Name: faktura_uz_import_progress faktura_uz_import_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faktura_uz_import_progress
    ADD CONSTRAINT faktura_uz_import_progress_pkey PRIMARY KEY (id);


--
-- Name: faktura_uz_params faktura_uz_params_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faktura_uz_params
    ADD CONSTRAINT faktura_uz_params_pkey PRIMARY KEY (id);


--
-- Name: farmer_data farmer_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.farmer_data
    ADD CONSTRAINT farmer_data_pkey PRIMARY KEY (id);


--
-- Name: fcm fcm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fcm
    ADD CONSTRAINT fcm_pkey PRIMARY KEY (id);


--
-- Name: funding_sources funding_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funding_sources
    ADD CONSTRAINT funding_sources_pkey PRIMARY KEY (id);


--
-- Name: general_invest general_invest_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.general_invest
    ADD CONSTRAINT general_invest_pkey PRIMARY KEY (id);


--
-- Name: gov_goods gov_goods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gov_goods
    ADD CONSTRAINT gov_goods_pkey PRIMARY KEY (id);


--
-- Name: household_response household_response_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT household_response_pkey PRIMARY KEY (id);


--
-- Name: hudud_gaz_gas_meter_info hudud_gaz_gas_meter_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hudud_gaz_gas_meter_info
    ADD CONSTRAINT hudud_gaz_gas_meter_info_pkey PRIMARY KEY (id);


--
-- Name: hudud_gaz_gas_meter_readings hudud_gaz_gas_meter_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hudud_gaz_gas_meter_readings
    ADD CONSTRAINT hudud_gaz_gas_meter_readings_pkey PRIMARY KEY (id);


--
-- Name: hudud_gaz_org_customer hudud_gaz_org_customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hudud_gaz_org_customer
    ADD CONSTRAINT hudud_gaz_org_customer_pkey PRIMARY KEY (id);


--
-- Name: implementation_projects implementation_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.implementation_projects
    ADD CONSTRAINT implementation_projects_pkey PRIMARY KEY (id);


--
-- Name: import_log import_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.import_log
    ADD CONSTRAINT import_log_pkey PRIMARY KEY (id);


--
-- Name: income_outcome income_outcome_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.income_outcome
    ADD CONSTRAINT income_outcome_pkey PRIMARY KEY (id);


--
-- Name: investment_comment investment_comment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_comment
    ADD CONSTRAINT investment_comment_pkey PRIMARY KEY (id);


--
-- Name: investment_funding_source_info investment_funding_source_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_funding_source_info
    ADD CONSTRAINT investment_funding_source_info_pkey PRIMARY KEY (doc_id);


--
-- Name: investment investment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment
    ADD CONSTRAINT investment_pkey PRIMARY KEY (id);


--
-- Name: investment_project_finance_info investment_project_finance_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_project_finance_info
    ADD CONSTRAINT investment_project_finance_info_pkey PRIMARY KEY (doc_id);


--
-- Name: investment_project_funding_source investment_project_funding_source_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_project_funding_source
    ADD CONSTRAINT investment_project_funding_source_pkey PRIMARY KEY (id);


--
-- Name: investment_project investment_project_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_project
    ADD CONSTRAINT investment_project_pkey PRIMARY KEY (id);


--
-- Name: investment_project_schedule_event investment_project_schedule_event_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_project_schedule_event
    ADD CONSTRAINT investment_project_schedule_event_pkey PRIMARY KEY (id);


--
-- Name: investment_projects investment_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_projects
    ADD CONSTRAINT investment_projects_pkey PRIMARY KEY (doc_id);


--
-- Name: investment_step investment_step_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_step
    ADD CONSTRAINT investment_step_pkey PRIMARY KEY (id);


--
-- Name: item_availability item_availability_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_availability
    ADD CONSTRAINT item_availability_pkey PRIMARY KEY (id);


--
-- Name: legal_entity_debt_import_progress legal_entity_debt_import_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.legal_entity_debt_import_progress
    ADD CONSTRAINT legal_entity_debt_import_progress_pkey PRIMARY KEY (id);


--
-- Name: legal_entity_debt legal_entity_debt_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.legal_entity_debt
    ADD CONSTRAINT legal_entity_debt_pkey PRIMARY KEY (id);


--
-- Name: limit_report limit_report_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.limit_report
    ADD CONSTRAINT limit_report_pkey PRIMARY KEY (id);


--
-- Name: log_progress log_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_progress
    ADD CONSTRAINT log_progress_pkey PRIMARY KEY (id);


--
-- Name: lot lot_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot
    ADD CONSTRAINT lot_pkey PRIMARY KEY (id);


--
-- Name: measurement_unit measurement_unit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.measurement_unit
    ADD CONSTRAINT measurement_unit_pkey PRIMARY KEY (id);


--
-- Name: message message_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- Name: meter_block meter_block_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_block
    ADD CONSTRAINT meter_block_pkey PRIMARY KEY (id);


--
-- Name: mip2hududgaz_payments mip2hududgaz_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mip2hududgaz_payments
    ADD CONSTRAINT mip2hududgaz_payments_pkey PRIMARY KEY (id);


--
-- Name: mip2import_progress mip2import_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mip2import_progress
    ADD CONSTRAINT mip2import_progress_pkey PRIMARY KEY (id);


--
-- Name: mixed_sold_lot_faktura_doc mixed_sold_lot_faktura_doc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mixed_sold_lot_faktura_doc
    ADD CONSTRAINT mixed_sold_lot_faktura_doc_pkey PRIMARY KEY (id);


--
-- Name: mobile_version mobile_version_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mobile_version
    ADD CONSTRAINT mobile_version_pkey PRIMARY KEY (id);


--
-- Name: navoiy_azot_transfer navoiy_azot_transfer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navoiy_azot_transfer
    ADD CONSTRAINT navoiy_azot_transfer_pkey PRIMARY KEY (id);


--
-- Name: notification notification_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_pkey PRIMARY KEY (id);


--
-- Name: operation operation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operation
    ADD CONSTRAINT operation_pkey PRIMARY KEY (id);


--
-- Name: organization_1c organization_1c_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_1c
    ADD CONSTRAINT organization_1c_pkey PRIMARY KEY (id);


--
-- Name: organization_bank_account_saldos organization_bank_account_saldos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_bank_account_saldos
    ADD CONSTRAINT organization_bank_account_saldos_pkey PRIMARY KEY (id);


--
-- Name: organization_bank_account_transactions organization_bank_account_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_bank_account_transactions
    ADD CONSTRAINT organization_bank_account_transactions_pkey PRIMARY KEY (id);


--
-- Name: organization_bank_accounts organization_bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_bank_accounts
    ADD CONSTRAINT organization_bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: organization_meters organization_meters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_meters
    ADD CONSTRAINT organization_meters_pkey PRIMARY KEY (id);


--
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- Name: other_docs other_docs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.other_docs
    ADD CONSTRAINT other_docs_pkey PRIMARY KEY (id);


--
-- Name: payment_block payment_block_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_block
    ADD CONSTRAINT payment_block_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: personal_check personal_check_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_check
    ADD CONSTRAINT personal_check_pkey PRIMARY KEY (id);


--
-- Name: personal personal_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal
    ADD CONSTRAINT personal_pkey PRIMARY KEY (id);


--
-- Name: personal_salary personal_salary_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_salary
    ADD CONSTRAINT personal_salary_pkey PRIMARY KEY (id);


--
-- Name: plan_monthly_values plan_monthly_values_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_monthly_values
    ADD CONSTRAINT plan_monthly_values_pkey PRIMARY KEY (id);


--
-- Name: plan plan_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan
    ADD CONSTRAINT plan_pkey PRIMARY KEY (id);


--
-- Name: position position_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."position"
    ADD CONSTRAINT position_pkey PRIMARY KEY (id);


--
-- Name: product product_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);


--
-- Name: product_tiftn_code product_tiftn_code_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_tiftn_code
    ADD CONSTRAINT product_tiftn_code_pkey PRIMARY KEY (id);


--
-- Name: product_workshop_plan product_workshop_plan_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_workshop_plan
    ADD CONSTRAINT product_workshop_plan_pkey PRIMARY KEY (id);


--
-- Name: profit_loss_1c profit_loss_1c_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profit_loss_1c
    ADD CONSTRAINT profit_loss_1c_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: queue_code queue_code_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.queue_code
    ADD CONSTRAINT queue_code_pkey PRIMARY KEY (id);


--
-- Name: reading_block reading_block_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reading_block
    ADD CONSTRAINT reading_block_pkey PRIMARY KEY (id);


--
-- Name: readings readings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.readings
    ADD CONSTRAINT readings_pkey PRIMARY KEY (id);


--
-- Name: region region_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.region
    ADD CONSTRAINT region_pkey PRIMARY KEY (id);


--
-- Name: relatives relatives_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relatives
    ADD CONSTRAINT relatives_pkey PRIMARY KEY (id);


--
-- Name: report_document report_document_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_document
    ADD CONSTRAINT report_document_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: saldo_period saldo_period_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saldo_period
    ADD CONSTRAINT saldo_period_pkey PRIMARY KEY (id);


--
-- Name: scale_attach scale_attach_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scale_attach
    ADD CONSTRAINT scale_attach_pkey PRIMARY KEY (id);


--
-- Name: scale scale_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scale
    ADD CONSTRAINT scale_pkey PRIMARY KEY (id);


--
-- Name: shlagbaun shlagbaun_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shlagbaun
    ADD CONSTRAINT shlagbaun_pkey PRIMARY KEY (id);


--
-- Name: sold_lot sold_lot_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sold_lot
    ADD CONSTRAINT sold_lot_pkey PRIMARY KEY (id);


--
-- Name: staff_and_technics staff_and_technics_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_and_technics
    ADD CONSTRAINT staff_and_technics_pkey PRIMARY KEY (id);


--
-- Name: staff_position_personal staff_position_personal_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_position_personal
    ADD CONSTRAINT staff_position_personal_pkey PRIMARY KEY (staff_position_id, personal_id);


--
-- Name: staff_position staff_position_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_position
    ADD CONSTRAINT staff_position_pkey PRIMARY KEY (id);


--
-- Name: stock_income_output_detail stock_income_output_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_income_output_detail
    ADD CONSTRAINT stock_income_output_detail_pkey PRIMARY KEY (id);


--
-- Name: technic technic_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technic
    ADD CONSTRAINT technic_pkey PRIMARY KEY (id);


--
-- Name: technic_type technic_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technic_type
    ADD CONSTRAINT technic_type_pkey PRIMARY KEY (id);


--
-- Name: trade_offers trade_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trade_offers
    ADD CONSTRAINT trade_offers_pkey PRIMARY KEY (id);


--
-- Name: transfer transfer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT transfer_pkey PRIMARY KEY (id);


--
-- Name: transfer_status_change transfer_status_change_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer_status_change
    ADD CONSTRAINT transfer_status_change_pkey PRIMARY KEY (id);


--
-- Name: transgaz_organization transgaz_organization_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transgaz_organization
    ADD CONSTRAINT transgaz_organization_pkey PRIMARY KEY (id);


--
-- Name: transgaz_point transgaz_point_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transgaz_point
    ADD CONSTRAINT transgaz_point_pkey PRIMARY KEY (id);


--
-- Name: transgaz_point_readings transgaz_point_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transgaz_point_readings
    ADD CONSTRAINT transgaz_point_readings_pkey PRIMARY KEY (id);


--
-- Name: ttn ttn_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ttn
    ADD CONSTRAINT ttn_pkey PRIMARY KEY (id);


--
-- Name: electricity_legal_entity uk10hvolq2duxf1cgnllrjoasy4; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT uk10hvolq2duxf1cgnllrjoasy4 UNIQUE (meters_id);


--
-- Name: electricity_legal_entity uk42fs2r615asalolyv9w6y8mx9; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT uk42fs2r615asalolyv9w6y8mx9 UNIQUE (payments_id);


--
-- Name: report_document uk81i9rtwpfsapj77agu0t3blsn; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_document
    ADD CONSTRAINT uk81i9rtwpfsapj77agu0t3blsn UNIQUE (c1id);


--
-- Name: camera uk83iofr88gx11wu0q67kk7xe05; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camera
    ADD CONSTRAINT uk83iofr88gx11wu0q67kk7xe05 UNIQUE (camera_id);


--
-- Name: household_response uk8ej1kjn7inaaci5org53k7n9c; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT uk8ej1kjn7inaaci5org53k7n9c UNIQUE (payments_id);


--
-- Name: household_response uk8pyrxmy70mh82ybtb8yqtvgej; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT uk8pyrxmy70mh82ybtb8yqtvgej UNIQUE (other_docs_id);


--
-- Name: drivers_info uk9d8061s1io52egsleur8yqmne; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers_info
    ADD CONSTRAINT uk9d8061s1io52egsleur8yqmne UNIQUE (transport_number);


--
-- Name: electricity_legal_entity uk9yhneffidrwwbqfoosnrl7fc7; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT uk9yhneffidrwwbqfoosnrl7fc7 UNIQUE (readings_id);


--
-- Name: electric_meters uk_meter_no_freeze_date; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electric_meters
    ADD CONSTRAINT uk_meter_no_freeze_date UNIQUE (meter_no, freeze_date);


--
-- Name: personal_check ukgryk70kb92nfw0r8g3mgtbg4q; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_check
    ADD CONSTRAINT ukgryk70kb92nfw0r8g3mgtbg4q UNIQUE (pinfl);


--
-- Name: household_response ukhinl7buejn40rqafyvgmlwr4n; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT ukhinl7buejn40rqafyvgmlwr4n UNIQUE (saldo_period_id);


--
-- Name: farmer_data ukjlrfg54dh2exu1k3viuwu6yh; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.farmer_data
    ADD CONSTRAINT ukjlrfg54dh2exu1k3viuwu6yh UNIQUE (inn);


--
-- Name: organization_meters ukkmju2q2ppcm0ig0olnfspql14; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_meters
    ADD CONSTRAINT ukkmju2q2ppcm0ig0olnfspql14 UNIQUE (organization_id, meter_no);


--
-- Name: household_response ukpgdxprry23c7g5huhwooq4587; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT ukpgdxprry23c7g5huhwooq4587 UNIQUE (readings_id);


--
-- Name: position ukqe48lxuex3swuovou3giy8qpk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."position"
    ADD CONSTRAINT ukqe48lxuex3swuovou3giy8qpk UNIQUE (name);


--
-- Name: users ukr43af9ap4edm43mmtq01oddj6; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT ukr43af9ap4edm43mmtq01oddj6 UNIQUE (username);


--
-- Name: department uksk6pr7ngt5r55va8kkom6l4q8; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT uksk6pr7ngt5r55va8kkom6l4q8 UNIQUE (c1id);


--
-- Name: electricity_legal_entity uktdbmiuhiqbf004vfat5gd9f87; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT uktdbmiuhiqbf004vfat5gd9f87 UNIQUE (saldo_period_id);


--
-- Name: limit_report unique_c1id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.limit_report
    ADD CONSTRAINT unique_c1id UNIQUE (c1id);


--
-- Name: electric_meters unique_meter_date; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electric_meters
    ADD CONSTRAINT unique_meter_date UNIQUE (meter_no, freeze_date);


--
-- Name: warehouse_amount unique_warehouse_amount; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_amount
    ADD CONSTRAINT unique_warehouse_amount UNIQUE (organization_id, warehouse_id, product_id);


--
-- Name: warehouse_balance unique_warehouse_balance; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_balance
    ADD CONSTRAINT unique_warehouse_balance UNIQUE (organization_id, warehouse_id, product_id, product_name);


--
-- Name: user_1c_organization user_1c_organization_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_1c_organization
    ADD CONSTRAINT user_1c_organization_pkey PRIMARY KEY (id);


--
-- Name: user_ability user_ability_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_ability
    ADD CONSTRAINT user_ability_pkey PRIMARY KEY (id);


--
-- Name: user_action_log user_action_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_action_log
    ADD CONSTRAINT user_action_log_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: user_user_ability user_user_ability_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_user_ability
    ADD CONSTRAINT user_user_ability_pkey PRIMARY KEY (user_ability_id, user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: warehouse_amount warehouse_amount_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_amount
    ADD CONSTRAINT warehouse_amount_pkey PRIMARY KEY (id);


--
-- Name: warehouse_balance warehouse_balance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_balance
    ADD CONSTRAINT warehouse_balance_pkey PRIMARY KEY (id);


--
-- Name: warehouse warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (id);


--
-- Name: warehouse_stock_income_output warehouse_stock_income_output_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_stock_income_output
    ADD CONSTRAINT warehouse_stock_income_output_pkey PRIMARY KEY (id);


--
-- Name: warehouse_stock warehouse_stock_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_stock
    ADD CONSTRAINT warehouse_stock_pkey PRIMARY KEY (id);


--
-- Name: water_consumption water_consumption_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.water_consumption
    ADD CONSTRAINT water_consumption_pkey PRIMARY KEY (id);


--
-- Name: weight weight_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.weight
    ADD CONSTRAINT weight_pkey PRIMARY KEY (id);


--
-- Name: workshop_assignment workshop_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workshop_assignment
    ADD CONSTRAINT workshop_assignment_pkey PRIMARY KEY (id);


--
-- Name: workshop workshop_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workshop
    ADD CONSTRAINT workshop_pkey PRIMARY KEY (id);


--
-- Name: idx_account_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_account_number ON public.organization_bank_account_saldos USING btree (account_number);


--
-- Name: idx_bargain_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_bargain_status ON public.sold_lot USING btree (bargain_status);


--
-- Name: idx_buyer_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_buyer_inn ON public.crop_and_sold_lot_dto USING btree (buyer_inn);


--
-- Name: idx_contract; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contract ON public.faktura_uz_document USING btree (contract);


--
-- Name: idx_contract_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contract_number ON public.faktura_uz_document_content USING btree (contract_number);


--
-- Name: idx_contract_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contract_type ON public.sold_lot USING btree (contract_type);


--
-- Name: idx_contractor_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contractor_inn ON public.faktura_uz_document USING btree (contractor_inn);


--
-- Name: idx_created_as_datetime; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_created_as_datetime ON public.faktura_uz_document USING btree (created_date_time_as_date_time);


--
-- Name: idx_crop_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crop_id ON public.crop USING btree (crop_id);


--
-- Name: idx_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_date ON public.lot USING btree (date);


--
-- Name: idx_date_as_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_date_as_date ON public.organization_bank_account_transactions USING btree (date_as_date);


--
-- Name: idx_delivery_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_date ON public.sold_lot USING btree (delivery_date);


--
-- Name: idx_district_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_district_code ON public.crop USING btree (district_code);


--
-- Name: idx_doc_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_doc_id ON public.organization_bank_account_transactions USING btree (doc_id);


--
-- Name: idx_farmer_cad_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_farmer_cad_number ON public.crop USING btree (farmer_cad_number);


--
-- Name: idx_farmer_tax_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_farmer_tax_number ON public.crop USING btree (farmer_tax_number);


--
-- Name: idx_harvest_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_harvest_code ON public.crop USING btree (harvest_code);


--
-- Name: idx_harvest_sort_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_harvest_sort_code ON public.crop USING btree (harvest_sort_code);


--
-- Name: idx_harvest_year; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_harvest_year ON public.crop USING btree (harvest_year);


--
-- Name: idx_included_in_saldo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_included_in_saldo ON public.organization_bank_accounts USING btree (included_in_saldo_calculation);


--
-- Name: idx_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_inn ON public.farmer_data USING btree (inn);


--
-- Name: idx_lead_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lead_id ON public.organization_bank_account_transactions USING btree (lead_id);


--
-- Name: idx_lot_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lot_id ON public.sold_lot USING btree (lot_id);


--
-- Name: idx_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_org_id ON public.organization_bank_account_transactions USING btree (organization_id);


--
-- Name: idx_organization_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_organization_id ON public.faktura_uz_document USING btree (organization_id);


--
-- Name: idx_organization_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_organization_inn ON public.faktura_uz_document USING btree (organization_inn);


--
-- Name: idx_owner_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_owner_inn ON public.faktura_uz_document_content USING btree (owner_inn);


--
-- Name: idx_pay_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pay_date ON public.sold_lot USING btree (pay_date);


--
-- Name: idx_place_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_place_code ON public.crop USING btree (place_code);


--
-- Name: idx_rcvr_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_rcvr_inn ON public.organization_bank_account_transactions USING btree (rcvr_inn);


--
-- Name: idx_region_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_region_code ON public.crop USING btree (region_code);


--
-- Name: idx_seller_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_seller_inn ON public.crop_and_sold_lot_dto USING btree (seller_inn);


--
-- Name: idx_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_session ON public.lot USING btree (session);


--
-- Name: idx_sndr_inn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sndr_inn ON public.organization_bank_account_transactions USING btree (sndr_inn);


--
-- Name: idx_state_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_state_id ON public.organization_bank_account_transactions USING btree (state_id);


--
-- Name: idx_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_status ON public.faktura_uz_document USING btree (status);


--
-- Name: idx_transaction_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transaction_date ON public.sold_lot USING btree (transaction_date);


--
-- Name: idx_transaction_date_as_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transaction_date_as_date ON public.sold_lot USING btree (transaction_date_as_date);


--
-- Name: idx_transaction_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transaction_number ON public.sold_lot USING btree (transaction_number);


--
-- Name: idx_transaction_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transaction_type ON public.organization_bank_account_transactions USING btree (transaction_type);


--
-- Name: idx_transfer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transfer_id ON public.ttn USING btree (transfer_id);


--
-- Name: idx_ttn_unique_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ttn_unique_id ON public.ttn USING btree (unique_id);


--
-- Name: idx_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_type ON public.faktura_uz_document USING btree (type);


--
-- Name: idx_unique_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_unique_id ON public.faktura_uz_document USING btree (unique_id);


--
-- Name: idx_watering; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_watering ON public.crop USING btree (watering);


--
-- Name: warehouse_stock_income_output_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX warehouse_stock_income_output_index ON public.warehouse_stock_income_output USING btree (organization_id, warehouse_id, inn, product_id, period);


--
-- Name: transfer trg_update_warehouse_amount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_warehouse_amount AFTER INSERT OR DELETE OR UPDATE ON public.transfer FOR EACH STATEMENT EXECUTE FUNCTION public.update_warehouse_amount();


--
-- Name: transfer trg_update_warehouse_balance; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_warehouse_balance AFTER INSERT OR UPDATE ON public.transfer FOR EACH STATEMENT EXECUTE FUNCTION public.update_warehouse_balance();


--
-- Name: transfer trigger_update_warehouse_amount; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_warehouse_amount AFTER INSERT OR UPDATE ON public.transfer FOR EACH ROW EXECUTE FUNCTION public.update_warehouse_amount();


--
-- Name: department_personal fk11monipx5pv8dvij2rgsytrme; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_personal
    ADD CONSTRAINT fk11monipx5pv8dvij2rgsytrme FOREIGN KEY (department_id) REFERENCES public.department(id);


--
-- Name: camera fk19gjr563x0tnyv2uhyg5qy26g; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camera
    ADD CONSTRAINT fk19gjr563x0tnyv2uhyg5qy26g FOREIGN KEY (investment_id) REFERENCES public.investment_project(id);


--
-- Name: contr_agent fk1hh7u3pcnjfrjuaohw47p1p6u; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contr_agent
    ADD CONSTRAINT fk1hh7u3pcnjfrjuaohw47p1p6u FOREIGN KEY (district_id) REFERENCES public.district(id);


--
-- Name: implementation_projects fk1kwsxo6v2qob9pm2b1mpjhchf; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.implementation_projects
    ADD CONSTRAINT fk1kwsxo6v2qob9pm2b1mpjhchf FOREIGN KEY (all_investment_id) REFERENCES public.all_investment(id);


--
-- Name: application_divorce fk1lwt6bod0v3f21gbb9x7vmjey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.application_divorce
    ADD CONSTRAINT fk1lwt6bod0v3f21gbb9x7vmjey FOREIGN KEY (application_id) REFERENCES public.application(id);


--
-- Name: technic fk1p17alcuk8x54t91yoap9ca3f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technic
    ADD CONSTRAINT fk1p17alcuk8x54t91yoap9ca3f FOREIGN KEY (type_id) REFERENCES public.technic_type(id);


--
-- Name: electricity_legal_entity fk1wgnkksk3i7nbejagxgq75cyd; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT fk1wgnkksk3i7nbejagxgq75cyd FOREIGN KEY (readings_id) REFERENCES public.reading_block(id);


--
-- Name: attachment fk2evmblk2twvu7s6nym7dpjxk2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT fk2evmblk2twvu7s6nym7dpjxk2 FOREIGN KEY (camera_id) REFERENCES public.camera(id);


--
-- Name: household_response fk2pd2aqjtkjjkgvduq4jo6ew6f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT fk2pd2aqjtkjjkgvduq4jo6ew6f FOREIGN KEY (readings_id) REFERENCES public.readings(id);


--
-- Name: staff_position fk2rccfqg11kksq37ku44aforg5; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_position
    ADD CONSTRAINT fk2rccfqg11kksq37ku44aforg5 FOREIGN KEY (department_id) REFERENCES public.department(id);


--
-- Name: warehouse_balance fk30mkn1s49k1ps85u08j7rkhow; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_balance
    ADD CONSTRAINT fk30mkn1s49k1ps85u08j7rkhow FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: personal fk33i80qi0r82hlhoaern2972c8; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal
    ADD CONSTRAINT fk33i80qi0r82hlhoaern2972c8 FOREIGN KEY (department_id) REFERENCES public.department(id);


--
-- Name: warehouse fk363w26pip2e3j8p65pao5xkvc; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT fk363w26pip2e3j8p65pao5xkvc FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: mixed_sold_lot_faktura_doc fk3744p5y2tf2162kasyf5lo0mw; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mixed_sold_lot_faktura_doc
    ADD CONSTRAINT fk3744p5y2tf2162kasyf5lo0mw FOREIGN KEY (navoiy_azot_transfer_id) REFERENCES public.navoiy_azot_transfer(id);


--
-- Name: department_personal fk3b09446451yk5drt2bydyi7cu; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_personal
    ADD CONSTRAINT fk3b09446451yk5drt2bydyi7cu FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: department_personals fk3ulu93ch6vrd5nfnownaknfxm; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_personals
    ADD CONSTRAINT fk3ulu93ch6vrd5nfnownaknfxm FOREIGN KEY (personals_id) REFERENCES public.personal(id);


--
-- Name: electricity_legal_entity fk3uy47o1ccjgr8ti2wqy62vo4q; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT fk3uy47o1ccjgr8ti2wqy62vo4q FOREIGN KEY (payments_id) REFERENCES public.payment_block(id);


--
-- Name: carrier fk403l68ahhkk6y0mwuy8f8yrjc; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carrier
    ADD CONSTRAINT fk403l68ahhkk6y0mwuy8f8yrjc FOREIGN KEY (cars_id) REFERENCES public.car(id);


--
-- Name: carrier fk444ampgxagiyornj1curpihke; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carrier
    ADD CONSTRAINT fk444ampgxagiyornj1curpihke FOREIGN KEY (delivers_id) REFERENCES public.deliver(id);


--
-- Name: electricity_legal_entity fk4eraob3ehrcow845rg01afgqh; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT fk4eraob3ehrcow845rg01afgqh FOREIGN KEY (meters_id) REFERENCES public.meter_block(id);


--
-- Name: staff_position_personal fk4g6cca23bg6rac107ys84xohl; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_position_personal
    ADD CONSTRAINT fk4g6cca23bg6rac107ys84xohl FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: relatives fk4h0dy43xby5d26kswm5po78dq; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relatives
    ADD CONSTRAINT fk4h0dy43xby5d26kswm5po78dq FOREIGN KEY (region_id) REFERENCES public.region(id);


--
-- Name: warehouse_amount fk4r1r8cvovrgoil2w5f8lgcxif; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_amount
    ADD CONSTRAINT fk4r1r8cvovrgoil2w5f8lgcxif FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: personal_departments fk4rcc4e5e99ebhatf3odblj0tn; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_departments
    ADD CONSTRAINT fk4rcc4e5e99ebhatf3odblj0tn FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: user_action_log fk4u2mqi2ifkc6i5gdp71q6l4me; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_action_log
    ADD CONSTRAINT fk4u2mqi2ifkc6i5gdp71q6l4me FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users fk4wnocubvav3874r2psscq42jo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk4wnocubvav3874r2psscq42jo FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: personal fk52wxtckqgut7nx2o839p1swj2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal
    ADD CONSTRAINT fk52wxtckqgut7nx2o839p1swj2 FOREIGN KEY (region_id) REFERENCES public.region(id);


--
-- Name: technic fk533a8656ys7vo6ae0nyhm1hdc; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technic
    ADD CONSTRAINT fk533a8656ys7vo6ae0nyhm1hdc FOREIGN KEY (staff_technic_id) REFERENCES public.staff_and_technics(id);


--
-- Name: warehouse fk5afsyijpp50x66p7nkt2wil8h; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT fk5afsyijpp50x66p7nkt2wil8h FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: meter_block_kf_tr fk5wvdinxkmafp05lj7ol9c1h5f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_block_kf_tr
    ADD CONSTRAINT fk5wvdinxkmafp05lj7ol9c1h5f FOREIGN KEY (meter_block_id) REFERENCES public.meter_block(id);


--
-- Name: personal_relative fk61xlfq4fxwo56o7mjq9cqwmxh; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_relative
    ADD CONSTRAINT fk61xlfq4fxwo56o7mjq9cqwmxh FOREIGN KEY (relative_id) REFERENCES public.relatives(id);


--
-- Name: organization fk6k9fv7s99m04x22vueveflp81; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT fk6k9fv7s99m04x22vueveflp81 FOREIGN KEY (district_id) REFERENCES public.district(id);


--
-- Name: user_user_ability fk6ucf3ck8dtsja19g8w3dhn80a; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_user_ability
    ADD CONSTRAINT fk6ucf3ck8dtsja19g8w3dhn80a FOREIGN KEY (user_ability_id) REFERENCES public.user_ability(id);


--
-- Name: navoiy_azot_transfer fk7229n125kkhgwrdggci1g5xug; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navoiy_azot_transfer
    ADD CONSTRAINT fk7229n125kkhgwrdggci1g5xug FOREIGN KEY (sold_lot_id) REFERENCES public.sold_lot(id);


--
-- Name: organization_partner fk78e0wcxxqixmw952kivlv7kn; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_partner
    ADD CONSTRAINT fk78e0wcxxqixmw952kivlv7kn FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: warehouse_amount fk7fl5xps3o5ve3b9w7u3p8a6yb; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_amount
    ADD CONSTRAINT fk7fl5xps3o5ve3b9w7u3p8a6yb FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: saldo_period_saldo_in fk7m4mo6eo5u06gwgi5au24an8; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saldo_period_saldo_in
    ADD CONSTRAINT fk7m4mo6eo5u06gwgi5au24an8 FOREIGN KEY (saldo_period_id) REFERENCES public.saldo_period(id);


--
-- Name: eimzo fk83wkr1kkoxsran7o8jt0gq9m9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eimzo
    ADD CONSTRAINT fk83wkr1kkoxsran7o8jt0gq9m9 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: reading_block_reading fk8d7c6qjl6efsupigmnln8y4o0; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reading_block_reading
    ADD CONSTRAINT fk8d7c6qjl6efsupigmnln8y4o0 FOREIGN KEY (reading_block_id) REFERENCES public.reading_block(id);


--
-- Name: mixed_sold_lot_faktura_doc fk8pm9h3yd6jnivfqp0xwhi2k02; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mixed_sold_lot_faktura_doc
    ADD CONSTRAINT fk8pm9h3yd6jnivfqp0xwhi2k02 FOREIGN KEY (sold_lot_id) REFERENCES public.sold_lot(id);


--
-- Name: navoiy_azot_transfer fk91xd8u1ahqetw1my2jpown6w; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navoiy_azot_transfer
    ADD CONSTRAINT fk91xd8u1ahqetw1my2jpown6w FOREIGN KEY (from_warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: message fk9a25x9o5r7wguarxeon2a9tmr; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT fk9a25x9o5r7wguarxeon2a9tmr FOREIGN KEY (receiver_id) REFERENCES public.users(id);


--
-- Name: navoiy_azot_transfer fk9b17c0kqwn7mt4vqoep6ufgj3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navoiy_azot_transfer
    ADD CONSTRAINT fk9b17c0kqwn7mt4vqoep6ufgj3 FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: users fk9q8fdenwsqjwrjfivd5ovv5k3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk9q8fdenwsqjwrjfivd5ovv5k3 FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: limit_report_article fk9qxow3n432nyxsv60kljkrk9f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.limit_report_article
    ADD CONSTRAINT fk9qxow3n432nyxsv60kljkrk9f FOREIGN KEY (article_id) REFERENCES public.article(id);


--
-- Name: product_workshop_plan fka0a1wd90p4eh1prni3sul37ef; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_workshop_plan
    ADD CONSTRAINT fka0a1wd90p4eh1prni3sul37ef FOREIGN KEY (workshop_id) REFERENCES public.workshop(id);


--
-- Name: electricity_legal_entity fkag0nw32b7uwbjb07ruaavou1x; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.electricity_legal_entity
    ADD CONSTRAINT fkag0nw32b7uwbjb07ruaavou1x FOREIGN KEY (saldo_period_id) REFERENCES public.saldo_period(id);


--
-- Name: department_personals fkawawdnmad5b3ulk3y5avmnhvs; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_personals
    ADD CONSTRAINT fkawawdnmad5b3ulk3y5avmnhvs FOREIGN KEY (department_id) REFERENCES public.department(id);


--
-- Name: transfer fkaxhwbulyi26p3e6wu6xvnm4e9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkaxhwbulyi26p3e6wu6xvnm4e9 FOREIGN KEY (from_warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: message fkbi5avhe69aol2mb1lnm6r4o2p; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT fkbi5avhe69aol2mb1lnm6r4o2p FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: plan_monthly_values fkbls9hqar31jsub81cxgkr3is6; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_monthly_values
    ADD CONSTRAINT fkbls9hqar31jsub81cxgkr3is6 FOREIGN KEY (plan_id) REFERENCES public.plan(id);


--
-- Name: household_response fkbs2oc97obabckh3li9xrhw5kq; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT fkbs2oc97obabckh3li9xrhw5kq FOREIGN KEY (other_docs_id) REFERENCES public.other_docs(id);


--
-- Name: saldo_period_debit fkbstheschk886a5yf5rvcoo4m8; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saldo_period_debit
    ADD CONSTRAINT fkbstheschk886a5yf5rvcoo4m8 FOREIGN KEY (saldo_period_id) REFERENCES public.saldo_period(id);


--
-- Name: organization_partner fkcdrku3gtl522wjlcvbd2doknn; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_partner
    ADD CONSTRAINT fkcdrku3gtl522wjlcvbd2doknn FOREIGN KEY (partner_organization_id) REFERENCES public.organization(id);


--
-- Name: personal fkcfqdvlv14qw2n5ui1q6gqki8j; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal
    ADD CONSTRAINT fkcfqdvlv14qw2n5ui1q6gqki8j FOREIGN KEY (district_id) REFERENCES public.district(id);


--
-- Name: article fkcgg5kkexxy1usb9vrbkeh7ybd; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article
    ADD CONSTRAINT fkcgg5kkexxy1usb9vrbkeh7ybd FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: investment_project fkckwyadcrchw7yosli2dmtc0a7; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_project
    ADD CONSTRAINT fkckwyadcrchw7yosli2dmtc0a7 FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: transfer fkct8g2t15qs72d1w2rexc0w93w; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkct8g2t15qs72d1w2rexc0w93w FOREIGN KEY (doverennost_id) REFERENCES public.faktura_uz_document(id);


--
-- Name: transfer fkd2lc61j0riqku19w47b3eqlnw; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkd2lc61j0riqku19w47b3eqlnw FOREIGN KEY (warehouse_stock_income_output_id) REFERENCES public.warehouse_stock_income_output(id);


--
-- Name: reading_block_meter_type fkd4q1xbfuonm6bx6ayuywk0kyt; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reading_block_meter_type
    ADD CONSTRAINT fkd4q1xbfuonm6bx6ayuywk0kyt FOREIGN KEY (reading_block_id) REFERENCES public.reading_block(id);


--
-- Name: application fkdeki5ioff7h6u9lqqqds69l1s; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT fkdeki5ioff7h6u9lqqqds69l1s FOREIGN KEY (debt_credit_1c_id) REFERENCES public.debtor_creditor1c(id);


--
-- Name: staff_and_technics fkdidyyy3sc2had2v350kw375gx; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_and_technics
    ADD CONSTRAINT fkdidyyy3sc2had2v350kw375gx FOREIGN KEY (project_id) REFERENCES public.investment_project(id);


--
-- Name: household_response fkdjg4k2rvsplm5dh9fmdsbwgyx; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT fkdjg4k2rvsplm5dh9fmdsbwgyx FOREIGN KEY (saldo_period_id) REFERENCES public.saldo_period(id);


--
-- Name: item_availability fkds54ir11ksvyu9kty5nsaijo9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_availability
    ADD CONSTRAINT fkds54ir11ksvyu9kty5nsaijo9 FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: reading_block_reading_date fke1pkv4j6oehuueqlqvohiuwte; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reading_block_reading_date
    ADD CONSTRAINT fke1pkv4j6oehuueqlqvohiuwte FOREIGN KEY (reading_block_id) REFERENCES public.reading_block(id);


--
-- Name: staff_position_personal fkenwbelkxri3j1jo9cxwwhr4ex; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_position_personal
    ADD CONSTRAINT fkenwbelkxri3j1jo9cxwwhr4ex FOREIGN KEY (staff_position_id) REFERENCES public.staff_position(id);


--
-- Name: saldo_period_credit fkeoil39yyt7nkt8ybr1x7l7px3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saldo_period_credit
    ADD CONSTRAINT fkeoil39yyt7nkt8ybr1x7l7px3 FOREIGN KEY (saldo_period_id) REFERENCES public.saldo_period(id);


--
-- Name: meter_block_meter_rz fkf4bhs0qastnfk81iuqn4mt0ms; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_block_meter_rz
    ADD CONSTRAINT fkf4bhs0qastnfk81iuqn4mt0ms FOREIGN KEY (meter_block_id) REFERENCES public.meter_block(id);


--
-- Name: workshop_assignment fkfbqtnnvpablaqnwjkmd9yosm; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workshop_assignment
    ADD CONSTRAINT fkfbqtnnvpablaqnwjkmd9yosm FOREIGN KEY (workshop_id) REFERENCES public.workshop(id);


--
-- Name: attachment fkfdbf7odfc9mipsonkv7ug4d9p; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT fkfdbf7odfc9mipsonkv7ug4d9p FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: transfer fkfeutcfmjqkxv8tald4rf4eo1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkfeutcfmjqkxv8tald4rf4eo1 FOREIGN KEY (to_warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: report_document_article_id fkfg0fntte8g4147uydx5ewk9xr; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_document_article_id
    ADD CONSTRAINT fkfg0fntte8g4147uydx5ewk9xr FOREIGN KEY (report_document_id) REFERENCES public.report_document(id);


--
-- Name: household_response fkflf792ah9dw2flhxajamevpm5; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.household_response
    ADD CONSTRAINT fkflf792ah9dw2flhxajamevpm5 FOREIGN KEY (payments_id) REFERENCES public.payments(id);


--
-- Name: transfer fkg6q395bm7k85hacl4w5704qp1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkg6q395bm7k85hacl4w5704qp1 FOREIGN KEY (approved_user_id) REFERENCES public.users(id);


--
-- Name: navoiy_azot_transfer fkg7lqcmn32fow0vlcegjhabpdh; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navoiy_azot_transfer
    ADD CONSTRAINT fkg7lqcmn32fow0vlcegjhabpdh FOREIGN KEY (doverennost_id) REFERENCES public.faktura_uz_document(id);


--
-- Name: stock_income_output_detail fkgb6kpv8i2sd6kaopipe7po75g; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stock_income_output_detail
    ADD CONSTRAINT fkgb6kpv8i2sd6kaopipe7po75g FOREIGN KEY (warehouse_stock_income_output_id) REFERENCES public.warehouse_stock_income_output(id);


--
-- Name: transfer fkgbkpv7tu50wdmxn0ayd0ou1f1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkgbkpv7tu50wdmxn0ayd0ou1f1 FOREIGN KEY (factory_id) REFERENCES public.organization(id);


--
-- Name: mixed_sold_lot_faktura_doc fkgie5vbt7aiot5uig1nxlmfk58; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mixed_sold_lot_faktura_doc
    ADD CONSTRAINT fkgie5vbt7aiot5uig1nxlmfk58 FOREIGN KEY (doverennost_id) REFERENCES public.faktura_uz_document(id);


--
-- Name: fcm fkgqytl5g9o228n9he2mwp5hrus; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fcm
    ADD CONSTRAINT fkgqytl5g9o228n9he2mwp5hrus FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: department fkgt2jmae86v2aik1nklhdc2dnx; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT fkgt2jmae86v2aik1nklhdc2dnx FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: user_1c_organization fkgwpwqufxef9lh3vqb0irysxec; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_1c_organization
    ADD CONSTRAINT fkgwpwqufxef9lh3vqb0irysxec FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: driver fkh63i08o6nv6ycnob7xt9jdgrv; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver
    ADD CONSTRAINT fkh63i08o6nv6ycnob7xt9jdgrv FOREIGN KEY (navoiy_azot_transfer_id) REFERENCES public.navoiy_azot_transfer(id);


--
-- Name: user_roles fkh8ciramu9cc9q3qcqiv4ue8a6; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT fkh8ciramu9cc9q3qcqiv4ue8a6 FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: article fkh9e499pibnsp4n37w25ebl8ne; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article
    ADD CONSTRAINT fkh9e499pibnsp4n37w25ebl8ne FOREIGN KEY (parent_id) REFERENCES public.article(id);


--
-- Name: user_roles fkhfh9dx7w3ubf1co1vdev94g3f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT fkhfh9dx7w3ubf1co1vdev94g3f FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: meter_block_meter_date fkhl28qlcfgj040e6o3vwusn2oq; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_block_meter_date
    ADD CONSTRAINT fkhl28qlcfgj040e6o3vwusn2oq FOREIGN KEY (meter_block_id) REFERENCES public.meter_block(id);


--
-- Name: workshop_assignment fkhng0f7c78wljo68otjqkm4gt4; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workshop_assignment
    ADD CONSTRAINT fkhng0f7c78wljo68otjqkm4gt4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transfer fki8y1qoe9vhn119jqv7qotbrfe; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fki8y1qoe9vhn119jqv7qotbrfe FOREIGN KEY (warehouse_district_id) REFERENCES public.district(id);


--
-- Name: personal_awards fkicyssppgjmvqdu92m7g03a115; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_awards
    ADD CONSTRAINT fkicyssppgjmvqdu92m7g03a115 FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: user_user_ability fkis66dnorgresbyobfo8rqphix; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_user_ability
    ADD CONSTRAINT fkis66dnorgresbyobfo8rqphix FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: warehouse_balance fkj4s4q6jprc16pddf51y0ccepv; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_balance
    ADD CONSTRAINT fkj4s4q6jprc16pddf51y0ccepv FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: employee fkj5th7wl8uux7i1fj667ch46u; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT fkj5th7wl8uux7i1fj667ch46u FOREIGN KEY (staff_technic_id) REFERENCES public.staff_and_technics(id);


--
-- Name: investment fkjbjlv29py6j26l6iwr2qe81q7; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment
    ADD CONSTRAINT fkjbjlv29py6j26l6iwr2qe81q7 FOREIGN KEY (investment_step_id) REFERENCES public.investment_step(id);


--
-- Name: investment_comment fkjjm0o2krvc6hy2l60um5vag4k; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_comment
    ADD CONSTRAINT fkjjm0o2krvc6hy2l60um5vag4k FOREIGN KEY (investment_id) REFERENCES public.investment(id);


--
-- Name: department fkjxv00xar9yakwaff0of7tci4y; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT fkjxv00xar9yakwaff0of7tci4y FOREIGN KEY (department_type_id) REFERENCES public.department_types(id);


--
-- Name: employee fkk3i11yuktiern5hr2lc2ssedq; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT fkk3i11yuktiern5hr2lc2ssedq FOREIGN KEY (type_id) REFERENCES public.employee_type(id);


--
-- Name: limit_report fkk3pxe2700hutf4djvll9fec99; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.limit_report
    ADD CONSTRAINT fkk3pxe2700hutf4djvll9fec99 FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: funding_sources fkk3xtniwf4w0jasrrx5sxwxk4g; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funding_sources
    ADD CONSTRAINT fkk3xtniwf4w0jasrrx5sxwxk4g FOREIGN KEY (all_investment_id) REFERENCES public.all_investment(id);


--
-- Name: transfer fkkhsdxqvd269eur9x8fpndpq70; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkkhsdxqvd269eur9x8fpndpq70 FOREIGN KEY (farmer_district_id) REFERENCES public.district(id);


--
-- Name: transfer_status_change fkkjbtmxgro56uju1d6l2k84psu; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer_status_change
    ADD CONSTRAINT fkkjbtmxgro56uju1d6l2k84psu FOREIGN KEY (transfer_id) REFERENCES public.navoiy_azot_transfer(id);


--
-- Name: navoiy_azot_transfer fkl3hh1jkj5cpy081ntyhox6u2q; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.navoiy_azot_transfer
    ADD CONSTRAINT fkl3hh1jkj5cpy081ntyhox6u2q FOREIGN KEY (farmer_district_id) REFERENCES public.district(id);


--
-- Name: meter_block_tarif_price fklb5hyfyd797xh0beg8kwodonh; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_block_tarif_price
    ADD CONSTRAINT fklb5hyfyd797xh0beg8kwodonh FOREIGN KEY (meter_block_id) REFERENCES public.meter_block(id);


--
-- Name: limit_report_article fklf2g3b58ne43b14s8da83pd8c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.limit_report_article
    ADD CONSTRAINT fklf2g3b58ne43b14s8da83pd8c FOREIGN KEY (limit_report_id) REFERENCES public.limit_report(id);


--
-- Name: user_1c_organization fklgrfbw5k5jb54j46w2nsl5it9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_1c_organization
    ADD CONSTRAINT fklgrfbw5k5jb54j46w2nsl5it9 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: saldo_period_saldo_out fklj0c3kuphiv64etmc359hfw6a; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saldo_period_saldo_out
    ADD CONSTRAINT fklj0c3kuphiv64etmc359hfw6a FOREIGN KEY (saldo_period_id) REFERENCES public.saldo_period(id);


--
-- Name: report_document_article_id fkls6gc1x8oyjejpbhun8buu5na; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_document_article_id
    ADD CONSTRAINT fkls6gc1x8oyjejpbhun8buu5na FOREIGN KEY (article_id_id) REFERENCES public.article(id);


--
-- Name: personal_salary fkltvwggr3g72pb7ea04m7gpkd8; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_salary
    ADD CONSTRAINT fkltvwggr3g72pb7ea04m7gpkd8 FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: personal_job_names fkm361hcp7ykqsavf676189ok53; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_job_names
    ADD CONSTRAINT fkm361hcp7ykqsavf676189ok53 FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: department fkmgsnnmudxrwqidn4f64q8rp4o; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT fkmgsnnmudxrwqidn4f64q8rp4o FOREIGN KEY (parent_id) REFERENCES public.department(id);


--
-- Name: payment_block_pay_type fkmofswtk2vh5ejup5g3njajjc3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_block_pay_type
    ADD CONSTRAINT fkmofswtk2vh5ejup5g3njajjc3 FOREIGN KEY (payment_block_id) REFERENCES public.payment_block(id);


--
-- Name: warehouse fkn9j18l8syelgwi3ikkrcx5ptx; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT fkn9j18l8syelgwi3ikkrcx5ptx FOREIGN KEY (district_id) REFERENCES public.district(id);


--
-- Name: investment_step fkna72j8c3cyb5yyg3hbddh9ve5; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment_step
    ADD CONSTRAINT fkna72j8c3cyb5yyg3hbddh9ve5 FOREIGN KEY (investment_project_id) REFERENCES public.investment_project(id);


--
-- Name: message fkned2m3gxtb2rdthwy91a5oju2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT fkned2m3gxtb2rdthwy91a5oju2 FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: notification fknk4ftb5am9ubmkv1661h15ds9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT fknk4ftb5am9ubmkv1661h15ds9 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: warehouse_amount fknnfecrjwcwhl2f2omnbji2dan; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_amount
    ADD CONSTRAINT fknnfecrjwcwhl2f2omnbji2dan FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: payment_block_pay_sum fknrs5eppb91dwibpppfqu8n2xh; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_block_pay_sum
    ADD CONSTRAINT fknrs5eppb91dwibpppfqu8n2xh FOREIGN KEY (payment_block_id) REFERENCES public.payment_block(id);


--
-- Name: transfer fknv70egobii1dt1jct8x4xl6rv; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fknv70egobii1dt1jct8x4xl6rv FOREIGN KEY (cancelled_by_user_id) REFERENCES public.users(id);


--
-- Name: transfer fko8jnpvkf53ksuavl9fba61bjc; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fko8jnpvkf53ksuavl9fba61bjc FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: relatives fkoal3mub1hr66orx8bc1hv6q3l; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relatives
    ADD CONSTRAINT fkoal3mub1hr66orx8bc1hv6q3l FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: meter_block_meter_type fkocb3scny4cnv3b8sl0tv6o393; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_block_meter_type
    ADD CONSTRAINT fkocb3scny4cnv3b8sl0tv6o393 FOREIGN KEY (meter_block_id) REFERENCES public.meter_block(id);


--
-- Name: queue_code fkotk2wlhoglopkv2evvtmuehys; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.queue_code
    ADD CONSTRAINT fkotk2wlhoglopkv2evvtmuehys FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: export_data fkp303i5mu0o3a4ruq2psetnrjo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.export_data
    ADD CONSTRAINT fkp303i5mu0o3a4ruq2psetnrjo FOREIGN KEY (carrier_id) REFERENCES public.carrier(id);


--
-- Name: personal_departments fkp47gapruimpo0scjp3kgg899n; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_departments
    ADD CONSTRAINT fkp47gapruimpo0scjp3kgg899n FOREIGN KEY (departments_id) REFERENCES public.department(id);


--
-- Name: product_workshop_plan fkpi16ucyfy4qtc8sqhwg4wkgmw; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_workshop_plan
    ADD CONSTRAINT fkpi16ucyfy4qtc8sqhwg4wkgmw FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: district fkpjyu66maoe0h5uqfhle85e5vo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.district
    ADD CONSTRAINT fkpjyu66maoe0h5uqfhle85e5vo FOREIGN KEY (region_id) REFERENCES public.region(id);


--
-- Name: projects fkpkhmxlwi6w8r8835fdhq980l; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fkpkhmxlwi6w8r8835fdhq980l FOREIGN KEY (all_investment_id) REFERENCES public.all_investment(id);


--
-- Name: relatives fkq77vecmdvt9m03653hvyhqhl0; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relatives
    ADD CONSTRAINT fkq77vecmdvt9m03653hvyhqhl0 FOREIGN KEY (district_id) REFERENCES public.district(id);


--
-- Name: camera fkqbcjwxx1abbodbbqoe9vo00; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camera
    ADD CONSTRAINT fkqbcjwxx1abbodbbqoe9vo00 FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: meter_block_meter_no fkqbm2v6c0st7v41cvh2sbo0ne9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_block_meter_no
    ADD CONSTRAINT fkqbm2v6c0st7v41cvh2sbo0ne9 FOREIGN KEY (meter_block_id) REFERENCES public.meter_block(id);


--
-- Name: general_invest fkqv1s9xc9p4s8l3eb4ubg9svcx; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.general_invest
    ADD CONSTRAINT fkqv1s9xc9p4s8l3eb4ubg9svcx FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: application fkr7dxqnwu3rgug7du538brkedh; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT fkr7dxqnwu3rgug7du538brkedh FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: contr_agent fkrh8amboc1wshb97dywilkm6n3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contr_agent
    ADD CONSTRAINT fkrh8amboc1wshb97dywilkm6n3 FOREIGN KEY (region_id) REFERENCES public.region(id);


--
-- Name: reading_block_meter_no fkrydg7tgqbf46m7518hho4gi3a; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reading_block_meter_no
    ADD CONSTRAINT fkrydg7tgqbf46m7518hho4gi3a FOREIGN KEY (reading_block_id) REFERENCES public.reading_block(id);


--
-- Name: personal_relative fksjo3b7o8hlh5kho1j69bdke9v; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_relative
    ADD CONSTRAINT fksjo3b7o8hlh5kho1j69bdke9v FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: personal_foreign_languages fkspnue0kva8uusqrb1tltqmg9b; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_foreign_languages
    ADD CONSTRAINT fkspnue0kva8uusqrb1tltqmg9b FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: wagon_numbers fksxhwos7w9asq9a1gbhk0n587k; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wagon_numbers
    ADD CONSTRAINT fksxhwos7w9asq9a1gbhk0n587k FOREIGN KEY (shipment_id) REFERENCES public.enaklodnoy_shipment(id);


--
-- Name: warehouse_stock fkt0m789cxjwnlqotks47x9aj4n; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse_stock
    ADD CONSTRAINT fkt0m789cxjwnlqotks47x9aj4n FOREIGN KEY (approved_by_user_id) REFERENCES public.users(id);


--
-- Name: transfer fkt64cfngn8jtqxne5hshhru07u; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfer
    ADD CONSTRAINT fkt64cfngn8jtqxne5hshhru07u FOREIGN KEY (product_mxik_id) REFERENCES public.product(id);


--
-- Name: investment fktoe4egfohav40wss20xv1n9th; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investment
    ADD CONSTRAINT fktoe4egfohav40wss20xv1n9th FOREIGN KEY (district_id) REFERENCES public.district(id);


--
-- Name: payment_block_pay_date fktp4laa4yex1rk2wbby4ux8qdh; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_block_pay_date
    ADD CONSTRAINT fktp4laa4yex1rk2wbby4ux8qdh FOREIGN KEY (payment_block_id) REFERENCES public.payment_block(id);


--
-- Name: income_outcome fkuni4n48g4i3rgse2eqhlepy3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.income_outcome
    ADD CONSTRAINT fkuni4n48g4i3rgse2eqhlepy3 FOREIGN KEY (personal_id) REFERENCES public.personal(id);


--
-- Name: saldo_period_period fkvuakq4fff1oelwpdxnhame2d; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saldo_period_period
    ADD CONSTRAINT fkvuakq4fff1oelwpdxnhame2d FOREIGN KEY (saldo_period_id) REFERENCES public.saldo_period(id);


--
-- PostgreSQL database dump complete
--

