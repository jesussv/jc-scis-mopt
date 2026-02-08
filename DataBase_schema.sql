--
-- PostgreSQL database dump
--

\restrict sqWnQKP6rvetbESSpJgnyorGhKsyJYfOgdOkH3q7uknaaFEVThAPmIeUK5E5I5a

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1 (Debian 18.1-1.pgdg13+2)

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
-- Name: google_vacuum_mgmt; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA google_vacuum_mgmt;


--
-- Name: google_vacuum_mgmt; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS google_vacuum_mgmt WITH SCHEMA google_vacuum_mgmt;


--
-- Name: EXTENSION google_vacuum_mgmt; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION google_vacuum_mgmt IS 'extension for assistive operational tooling';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: jcstoragetype; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.jcstoragetype AS ENUM (
    'CLOUD_STORAGE',
    'INLINE'
);


--
-- Name: jctranstype; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.jctranstype AS ENUM (
    'IN',
    'OUT',
    'ADJUST',
    'TRANSFER'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: jcdocuref; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jcdocuref (
    recid uuid NOT NULL,
    inventtablerecid uuid NOT NULL,
    storagetype public.jcstoragetype DEFAULT 'CLOUD_STORAGE'::public.jcstoragetype NOT NULL,
    url text,
    storagebucket text,
    storagepath text,
    filecontent bytea,
    filetype text,
    filename text,
    filesize bigint,
    isdefault boolean DEFAULT false NOT NULL,
    createddatetime timestamp with time zone DEFAULT now() NOT NULL,
    createdbyrecid uuid
);


--
-- Name: jcinventlocation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jcinventlocation (
    recid uuid NOT NULL,
    inventlocationid text NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    createddatetime timestamp with time zone DEFAULT now() NOT NULL,
    modifieddatetime timestamp with time zone DEFAULT now() NOT NULL,
    createdbyrecid uuid,
    modifiedbyrecid uuid,
    ismobile boolean DEFAULT false NOT NULL,
    deviceid text,
    plate text,
    drivername text,
    latitude numeric(10,7),
    longitude numeric(10,7),
    accuracym numeric(10,2),
    locationupdatedat timestamp with time zone
);


--
-- Name: jcinventsum; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jcinventsum (
    inventtablerecid uuid NOT NULL,
    inventlocationrecid uuid NOT NULL,
    availphysical numeric(18,4) DEFAULT 0 NOT NULL,
    recversion bigint DEFAULT 0 NOT NULL,
    modifieddatetime timestamp with time zone DEFAULT now() NOT NULL,
    modifiedbyrecid uuid,
    batchid text DEFAULT ''::text NOT NULL,
    serialid text DEFAULT ''::text NOT NULL,
    CONSTRAINT ck_jcinventsum_availphysical_nonnegative CHECK ((availphysical >= (0)::numeric))
);


--
-- Name: jcinventtable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jcinventtable (
    recid uuid NOT NULL,
    itemid text NOT NULL,
    namealias text NOT NULL,
    barcode text,
    active boolean DEFAULT true NOT NULL,
    createddatetime timestamp with time zone DEFAULT now() NOT NULL,
    modifieddatetime timestamp with time zone DEFAULT now() NOT NULL,
    createdbyrecid uuid,
    modifiedbyrecid uuid
);


--
-- Name: jcinventtrans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jcinventtrans (
    recid uuid NOT NULL,
    inventtablerecid uuid NOT NULL,
    inventlocationrecid uuid NOT NULL,
    transtype public.jctranstype NOT NULL,
    qty numeric(18,4) NOT NULL,
    reason text,
    voucher text,
    createdbyrecid uuid NOT NULL,
    createddatetime timestamp with time zone DEFAULT now() NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    accuracym numeric(10,2),
    devicetime timestamp with time zone,
    batchid text DEFAULT ''::text NOT NULL,
    serialid text DEFAULT ''::text NOT NULL,
    toinventlocationrecid uuid,
    CONSTRAINT jcinventtrans_qty_check CHECK ((qty > (0)::numeric))
);


--
-- Name: jcuserinfo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jcuserinfo (
    recid uuid NOT NULL,
    userid text NOT NULL,
    email text,
    passwordhash text NOT NULL,
    passwordsalt text,
    active boolean DEFAULT true NOT NULL,
    lastlogondatetime timestamp with time zone,
    createddatetime timestamp with time zone DEFAULT now() NOT NULL,
    modifieddatetime timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: jcdocuref jcdocuref_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcdocuref
    ADD CONSTRAINT jcdocuref_pkey PRIMARY KEY (recid);


--
-- Name: jcinventlocation jcinventlocation_deviceid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventlocation
    ADD CONSTRAINT jcinventlocation_deviceid_key UNIQUE (deviceid);


--
-- Name: jcinventlocation jcinventlocation_inventlocationid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventlocation
    ADD CONSTRAINT jcinventlocation_inventlocationid_key UNIQUE (inventlocationid);


--
-- Name: jcinventlocation jcinventlocation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventlocation
    ADD CONSTRAINT jcinventlocation_pkey PRIMARY KEY (recid);


--
-- Name: jcinventsum jcinventsum_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventsum
    ADD CONSTRAINT jcinventsum_pkey PRIMARY KEY (inventtablerecid, inventlocationrecid);


--
-- Name: jcinventtable jcinventtable_barcode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtable
    ADD CONSTRAINT jcinventtable_barcode_key UNIQUE (barcode);


--
-- Name: jcinventtable jcinventtable_itemid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtable
    ADD CONSTRAINT jcinventtable_itemid_key UNIQUE (itemid);


--
-- Name: jcinventtable jcinventtable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtable
    ADD CONSTRAINT jcinventtable_pkey PRIMARY KEY (recid);


--
-- Name: jcinventtrans jcinventtrans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtrans
    ADD CONSTRAINT jcinventtrans_pkey PRIMARY KEY (recid);


--
-- Name: jcuserinfo jcuserinfo_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcuserinfo
    ADD CONSTRAINT jcuserinfo_email_key UNIQUE (email);


--
-- Name: jcuserinfo jcuserinfo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcuserinfo
    ADD CONSTRAINT jcuserinfo_pkey PRIMARY KEY (recid);


--
-- Name: jcuserinfo jcuserinfo_userid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcuserinfo
    ADD CONSTRAINT jcuserinfo_userid_key UNIQUE (userid);


--
-- Name: ix_jcdocuref_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcdocuref_item ON public.jcdocuref USING btree (inventtablerecid);


--
-- Name: ix_jcinventlocation_inventlocationid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventlocation_inventlocationid ON public.jcinventlocation USING btree (inventlocationid);


--
-- Name: ix_jcinventlocation_ismobile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventlocation_ismobile ON public.jcinventlocation USING btree (ismobile);


--
-- Name: ix_jcinventlocation_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventlocation_location ON public.jcinventlocation USING btree (latitude, longitude);


--
-- Name: ix_jcinventsum_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventsum_location ON public.jcinventsum USING btree (inventlocationrecid);


--
-- Name: ix_jcinventtable_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtable_barcode ON public.jcinventtable USING btree (barcode);


--
-- Name: ix_jcinventtable_namealias; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtable_namealias ON public.jcinventtable USING btree (namealias);


--
-- Name: ix_jcinventtrans_createdbydate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtrans_createdbydate ON public.jcinventtrans USING btree (createdbyrecid, createddatetime DESC);


--
-- Name: ix_jcinventtrans_item_loc_batch_serial; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtrans_item_loc_batch_serial ON public.jcinventtrans USING btree (inventtablerecid, inventlocationrecid, batchid, serialid);


--
-- Name: ix_jcinventtrans_item_loc_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtrans_item_loc_date ON public.jcinventtrans USING btree (inventtablerecid, inventlocationrecid, createddatetime DESC);


--
-- Name: ix_jcinventtrans_itemdate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtrans_itemdate ON public.jcinventtrans USING btree (inventtablerecid, createddatetime DESC);


--
-- Name: ix_jcinventtrans_locationdate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtrans_locationdate ON public.jcinventtrans USING btree (inventlocationrecid, createddatetime DESC);


--
-- Name: ix_jcinventtrans_to_loc_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcinventtrans_to_loc_date ON public.jcinventtrans USING btree (toinventlocationrecid, createddatetime DESC);


--
-- Name: ix_jcuserinfo_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcuserinfo_email ON public.jcuserinfo USING btree (email);


--
-- Name: ix_jcuserinfo_userid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jcuserinfo_userid ON public.jcuserinfo USING btree (userid);


--
-- Name: ux_jcdocuref_defaultperitem; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_jcdocuref_defaultperitem ON public.jcdocuref USING btree (inventtablerecid) WHERE (isdefault = true);


--
-- Name: ux_jcinventsum_item_loc_batch_serial; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_jcinventsum_item_loc_batch_serial ON public.jcinventsum USING btree (inventtablerecid, inventlocationrecid, batchid, serialid);


--
-- Name: jcdocuref jcdocuref_createdbyrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcdocuref
    ADD CONSTRAINT jcdocuref_createdbyrecid_fkey FOREIGN KEY (createdbyrecid) REFERENCES public.jcuserinfo(recid);


--
-- Name: jcdocuref jcdocuref_inventtablerecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcdocuref
    ADD CONSTRAINT jcdocuref_inventtablerecid_fkey FOREIGN KEY (inventtablerecid) REFERENCES public.jcinventtable(recid) ON DELETE CASCADE;


--
-- Name: jcinventlocation jcinventlocation_createdbyrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventlocation
    ADD CONSTRAINT jcinventlocation_createdbyrecid_fkey FOREIGN KEY (createdbyrecid) REFERENCES public.jcuserinfo(recid);


--
-- Name: jcinventlocation jcinventlocation_modifiedbyrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventlocation
    ADD CONSTRAINT jcinventlocation_modifiedbyrecid_fkey FOREIGN KEY (modifiedbyrecid) REFERENCES public.jcuserinfo(recid);


--
-- Name: jcinventsum jcinventsum_inventlocationrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventsum
    ADD CONSTRAINT jcinventsum_inventlocationrecid_fkey FOREIGN KEY (inventlocationrecid) REFERENCES public.jcinventlocation(recid);


--
-- Name: jcinventsum jcinventsum_inventtablerecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventsum
    ADD CONSTRAINT jcinventsum_inventtablerecid_fkey FOREIGN KEY (inventtablerecid) REFERENCES public.jcinventtable(recid);


--
-- Name: jcinventsum jcinventsum_modifiedbyrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventsum
    ADD CONSTRAINT jcinventsum_modifiedbyrecid_fkey FOREIGN KEY (modifiedbyrecid) REFERENCES public.jcuserinfo(recid);


--
-- Name: jcinventtable jcinventtable_createdbyrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtable
    ADD CONSTRAINT jcinventtable_createdbyrecid_fkey FOREIGN KEY (createdbyrecid) REFERENCES public.jcuserinfo(recid);


--
-- Name: jcinventtable jcinventtable_modifiedbyrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtable
    ADD CONSTRAINT jcinventtable_modifiedbyrecid_fkey FOREIGN KEY (modifiedbyrecid) REFERENCES public.jcuserinfo(recid);


--
-- Name: jcinventtrans jcinventtrans_createdbyrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtrans
    ADD CONSTRAINT jcinventtrans_createdbyrecid_fkey FOREIGN KEY (createdbyrecid) REFERENCES public.jcuserinfo(recid);


--
-- Name: jcinventtrans jcinventtrans_inventlocationrecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtrans
    ADD CONSTRAINT jcinventtrans_inventlocationrecid_fkey FOREIGN KEY (inventlocationrecid) REFERENCES public.jcinventlocation(recid);


--
-- Name: jcinventtrans jcinventtrans_inventtablerecid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jcinventtrans
    ADD CONSTRAINT jcinventtrans_inventtablerecid_fkey FOREIGN KEY (inventtablerecid) REFERENCES public.jcinventtable(recid);


--
-- PostgreSQL database dump complete
--

\unrestrict sqWnQKP6rvetbESSpJgnyorGhKsyJYfOgdOkH3q7uknaaFEVThAPmIeUK5E5I5a

