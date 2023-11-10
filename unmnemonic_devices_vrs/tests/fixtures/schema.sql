--
-- PostgreSQL database dump
--

-- Dumped from database version 13.9
-- Dumped by pg_dump version 13.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: _sqlx_test; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA _sqlx_test;


--
-- Name: unmnemonic_devices; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA unmnemonic_devices;


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: database_ids; Type: SEQUENCE; Schema: _sqlx_test; Owner: -
--

CREATE SEQUENCE _sqlx_test.database_ids
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: databases; Type: TABLE; Schema: _sqlx_test; Owner: -
--

CREATE TABLE _sqlx_test.databases (
    db_name text NOT NULL,
    test_path text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid NOT NULL,
    subject character varying(255),
    content text,
    ready boolean DEFAULT false,
    postmarked_at date,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    rendered_content text,
    show_team boolean,
    from_name character varying(255),
    from_address character varying(255)
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id uuid NOT NULL,
    name character varying(255),
    risk_aversion integer,
    notes text,
    user_ids uuid[] DEFAULT ARRAY[]::uuid[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    voicepass character varying(255),
    listens integer DEFAULT 0
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying(255),
    crypted_password character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    admin boolean,
    team_emails text,
    proposed_team_name text,
    risk_aversion integer,
    accessibility text,
    recovery_hash character varying(255),
    comments text,
    source text,
    attending boolean,
    voicepass character varying(255),
    remembered integer DEFAULT 0
);


--
-- Name: books; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.books (
    id uuid NOT NULL,
    excerpt character varying(255),
    title character varying(255)
);


--
-- Name: calls; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.calls (
    id character varying(255) NOT NULL,
    number character varying(255),
    team_id uuid,
    created_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: destinations; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.destinations (
    id uuid NOT NULL,
    description character varying(255),
    region_id uuid NOT NULL,
    answer character varying(255)
);


--
-- Name: meetings; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.meetings (
    id uuid NOT NULL,
    book_id uuid NOT NULL,
    destination_id uuid NOT NULL,
    team_id uuid NOT NULL,
    listens integer DEFAULT 0
);


--
-- Name: recordings; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.recordings (
    id uuid NOT NULL,
    type character varying(255),
    region_id uuid,
    destination_id uuid,
    book_id uuid,
    url character varying(255),
    transcription text,
    character_name character varying(255),
    prompt_name character varying(255),
    approved boolean DEFAULT false,
    team_listen_ids uuid[] DEFAULT ARRAY[]::uuid[],
    created_at timestamp(0) without time zone DEFAULT now(),
    call_id character varying(255),
    team_id uuid
);


--
-- Name: regions; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.regions (
    id uuid NOT NULL,
    name character varying(255),
    created_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: settings; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.settings (
    id bigint NOT NULL,
    override text,
    begun boolean DEFAULT false,
    compromised boolean DEFAULT false,
    ending boolean DEFAULT false,
    down boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    day_before boolean DEFAULT false,
    degrading boolean DEFAULT false,
    vrs_href character varying(255),
    vrs_human character varying(255)
);


--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: unmnemonic_devices; Owner: -
--

CREATE SEQUENCE unmnemonic_devices.settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: unmnemonic_devices; Owner: -
--

ALTER SEQUENCE unmnemonic_devices.settings_id_seq OWNED BY unmnemonic_devices.settings.id;


--
-- Name: settings id; Type: DEFAULT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.settings ALTER COLUMN id SET DEFAULT nextval('unmnemonic_devices.settings_id_seq'::regclass);


--
-- Name: databases databases_pkey; Type: CONSTRAINT; Schema: _sqlx_test; Owner: -
--

ALTER TABLE ONLY _sqlx_test.databases
    ADD CONSTRAINT databases_pkey PRIMARY KEY (db_name);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: books books_pkey; Type: CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (id);


--
-- Name: calls calls_pkey; Type: CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.calls
    ADD CONSTRAINT calls_pkey PRIMARY KEY (id);


--
-- Name: destinations destinations_pkey; Type: CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.destinations
    ADD CONSTRAINT destinations_pkey PRIMARY KEY (id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: recordings recordings_pkey; Type: CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.recordings
    ADD CONSTRAINT recordings_pkey PRIMARY KEY (id);


--
-- Name: regions regions_pkey; Type: CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: databases_created_at; Type: INDEX; Schema: _sqlx_test; Owner: -
--

CREATE INDEX databases_created_at ON _sqlx_test.databases USING btree (created_at);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: recordings_book_id_index; Type: INDEX; Schema: unmnemonic_devices; Owner: -
--

CREATE UNIQUE INDEX recordings_book_id_index ON unmnemonic_devices.recordings USING btree (book_id);


--
-- Name: recordings_character_name_prompt_name_index; Type: INDEX; Schema: unmnemonic_devices; Owner: -
--

CREATE UNIQUE INDEX recordings_character_name_prompt_name_index ON unmnemonic_devices.recordings USING btree (character_name, prompt_name);


--
-- Name: recordings_destination_id_index; Type: INDEX; Schema: unmnemonic_devices; Owner: -
--

CREATE UNIQUE INDEX recordings_destination_id_index ON unmnemonic_devices.recordings USING btree (destination_id);


--
-- Name: recordings_region_id_index; Type: INDEX; Schema: unmnemonic_devices; Owner: -
--

CREATE UNIQUE INDEX recordings_region_id_index ON unmnemonic_devices.recordings USING btree (region_id);


--
-- Name: recordings_team_id_index; Type: INDEX; Schema: unmnemonic_devices; Owner: -
--

CREATE UNIQUE INDEX recordings_team_id_index ON unmnemonic_devices.recordings USING btree (team_id);


--
-- Name: calls calls_team_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.calls
    ADD CONSTRAINT calls_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: destinations destinations_region_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.destinations
    ADD CONSTRAINT destinations_region_id_fkey FOREIGN KEY (region_id) REFERENCES unmnemonic_devices.regions(id);


--
-- Name: meetings meetings_book_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.meetings
    ADD CONSTRAINT meetings_book_id_fkey FOREIGN KEY (book_id) REFERENCES unmnemonic_devices.books(id);


--
-- Name: meetings meetings_destination_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.meetings
    ADD CONSTRAINT meetings_destination_id_fkey FOREIGN KEY (destination_id) REFERENCES unmnemonic_devices.destinations(id);


--
-- Name: meetings meetings_team_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.meetings
    ADD CONSTRAINT meetings_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: recordings recordings_book_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.recordings
    ADD CONSTRAINT recordings_book_id_fkey FOREIGN KEY (book_id) REFERENCES unmnemonic_devices.books(id);


--
-- Name: recordings recordings_call_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.recordings
    ADD CONSTRAINT recordings_call_id_fkey FOREIGN KEY (call_id) REFERENCES unmnemonic_devices.calls(id);


--
-- Name: recordings recordings_destination_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.recordings
    ADD CONSTRAINT recordings_destination_id_fkey FOREIGN KEY (destination_id) REFERENCES unmnemonic_devices.destinations(id);


--
-- Name: recordings recordings_region_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.recordings
    ADD CONSTRAINT recordings_region_id_fkey FOREIGN KEY (region_id) REFERENCES unmnemonic_devices.regions(id);


--
-- Name: recordings recordings_team_id_fkey; Type: FK CONSTRAINT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.recordings
    ADD CONSTRAINT recordings_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20151126220459);
INSERT INTO public."schema_migrations" (version) VALUES (20151129222538);
INSERT INTO public."schema_migrations" (version) VALUES (20151205214742);
INSERT INTO public."schema_migrations" (version) VALUES (20151206225612);
INSERT INTO public."schema_migrations" (version) VALUES (20151210224535);
INSERT INTO public."schema_migrations" (version) VALUES (20151212200844);
INSERT INTO public."schema_migrations" (version) VALUES (20160109155512);
INSERT INTO public."schema_migrations" (version) VALUES (20160110144310);
INSERT INTO public."schema_migrations" (version) VALUES (20160111030956);
INSERT INTO public."schema_migrations" (version) VALUES (20160116213130);
INSERT INTO public."schema_migrations" (version) VALUES (20160202232816);
INSERT INTO public."schema_migrations" (version) VALUES (20160210161806);
INSERT INTO public."schema_migrations" (version) VALUES (20230403015430);
INSERT INTO public."schema_migrations" (version) VALUES (20230403015446);
INSERT INTO public."schema_migrations" (version) VALUES (20230410042355);
INSERT INTO public."schema_migrations" (version) VALUES (20230411002346);
INSERT INTO public."schema_migrations" (version) VALUES (20230415020954);
INSERT INTO public."schema_migrations" (version) VALUES (20230415180333);
INSERT INTO public."schema_migrations" (version) VALUES (20230415180346);
INSERT INTO public."schema_migrations" (version) VALUES (20230415180351);
INSERT INTO public."schema_migrations" (version) VALUES (20230416192016);
INSERT INTO public."schema_migrations" (version) VALUES (20230419025011);
INSERT INTO public."schema_migrations" (version) VALUES (20230508143302);
INSERT INTO public."schema_migrations" (version) VALUES (20231025044059);
INSERT INTO public."schema_migrations" (version) VALUES (20231025052751);
INSERT INTO public."schema_migrations" (version) VALUES (20231029032644);
INSERT INTO public."schema_migrations" (version) VALUES (20231102005345);
INSERT INTO public."schema_migrations" (version) VALUES (20231102013852);
INSERT INTO public."schema_migrations" (version) VALUES (20231104170543);
INSERT INTO public."schema_migrations" (version) VALUES (20231105032326);
INSERT INTO public."schema_migrations" (version) VALUES (20231105153232);
INSERT INTO public."schema_migrations" (version) VALUES (20231105160034);
INSERT INTO public."schema_migrations" (version) VALUES (20231110024646);
INSERT INTO public."schema_migrations" (version) VALUES (20231110062026);
