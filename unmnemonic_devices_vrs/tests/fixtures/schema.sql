--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4 (Postgres.app)
-- Dumped by pg_dump version 16.4 (Postgres.app)

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
-- Name: unmnemonic_devices; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA unmnemonic_devices;


--
-- Name: waydowntown; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA waydowntown;


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


SET default_tablespace = '';

SET default_table_access_method = heap;

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
    name text,
    risk_aversion integer,
    notes text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    voicepass character varying(255),
    listens integer DEFAULT 0,
    name_truncated character varying(53) GENERATED ALWAYS AS (
CASE
    WHEN (length(name) > 50) THEN (SUBSTRING(name FROM 1 FOR (50 - POSITION((' '::text) IN (reverse(SUBSTRING(name FROM 1 FOR 50)))))) || '…'::text)
    ELSE name
END) STORED
);


--
-- Name: user_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_identities (
    id uuid NOT NULL,
    provider character varying(255) NOT NULL,
    uid character varying(255) NOT NULL,
    user_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255),
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
    remembered integer DEFAULT 0,
    team_id uuid,
    invitation_token character varying(255),
    invitation_accepted_at timestamp(0) without time zone,
    invited_by_id uuid
);


--
-- Name: books; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.books (
    id uuid NOT NULL,
    excerpt character varying(255),
    title character varying(255),
    inserted_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: calls; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.calls (
    id character varying(255) NOT NULL,
    number character varying(255),
    team_id uuid,
    inserted_at timestamp(0) without time zone DEFAULT now(),
    path character varying(255)
);


--
-- Name: destinations; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.destinations (
    id uuid NOT NULL,
    description character varying(255),
    region_id uuid NOT NULL,
    answer character varying(255),
    inserted_at timestamp(0) without time zone DEFAULT now()
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
    inserted_at timestamp(0) without time zone DEFAULT now(),
    call_id character varying(255),
    team_id uuid
);


--
-- Name: regions; Type: TABLE; Schema: unmnemonic_devices; Owner: -
--

CREATE TABLE unmnemonic_devices.regions (
    id uuid NOT NULL,
    name character varying(255),
    inserted_at timestamp(0) without time zone DEFAULT now()
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
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    vrs_href character varying(255),
    vrs_human character varying(255),
    notify_supervisor boolean DEFAULT true
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
-- Name: answers; Type: TABLE; Schema: waydowntown; Owner: -
--

CREATE TABLE waydowntown.answers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    answer character varying(255),
    game_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    correct boolean DEFAULT false
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: waydowntown; Owner: -
--

CREATE TABLE waydowntown.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: games; Type: TABLE; Schema: waydowntown; Owner: -
--

CREATE TABLE waydowntown.games (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incarnation_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    winner_answer_id uuid
);


--
-- Name: incarnations; Type: TABLE; Schema: waydowntown; Owner: -
--

CREATE TABLE waydowntown.incarnations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    concept character varying(255),
    mask character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    region_id uuid,
    answers character varying(255)[] DEFAULT ARRAY[]::character varying[],
    placed boolean DEFAULT true NOT NULL,
    start text
);


--
-- Name: regions; Type: TABLE; Schema: waydowntown; Owner: -
--

CREATE TABLE waydowntown.regions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255),
    description text,
    parent_id uuid,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    latitude numeric,
    longitude numeric
);


--
-- Name: settings id; Type: DEFAULT; Schema: unmnemonic_devices; Owner: -
--

ALTER TABLE ONLY unmnemonic_devices.settings ALTER COLUMN id SET DEFAULT nextval('unmnemonic_devices.settings_id_seq'::regclass);


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
-- Name: user_identities user_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_identities
    ADD CONSTRAINT user_identities_pkey PRIMARY KEY (id);


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
-- Name: answers answers_pkey; Type: CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.answers
    ADD CONSTRAINT answers_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


--
-- Name: incarnations incarnations_pkey; Type: CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.incarnations
    ADD CONSTRAINT incarnations_pkey PRIMARY KEY (id);


--
-- Name: regions regions_pkey; Type: CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (id);


--
-- Name: user_identities_uid_provider_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_identities_uid_provider_index ON public.user_identities USING btree (uid, provider);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: users_invitation_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_invitation_token_index ON public.users USING btree (invitation_token);


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
-- Name: incarnations_placed_index; Type: INDEX; Schema: waydowntown; Owner: -
--

CREATE INDEX incarnations_placed_index ON waydowntown.incarnations USING btree (placed);


--
-- Name: user_identities user_identities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_identities
    ADD CONSTRAINT user_identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users users_invited_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_invited_by_id_fkey FOREIGN KEY (invited_by_id) REFERENCES public.users(id);


--
-- Name: users users_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


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
-- Name: answers answers_game_id_fkey; Type: FK CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.answers
    ADD CONSTRAINT answers_game_id_fkey FOREIGN KEY (game_id) REFERENCES waydowntown.games(id);


--
-- Name: games games_incarnation_id_fkey; Type: FK CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.games
    ADD CONSTRAINT games_incarnation_id_fkey FOREIGN KEY (incarnation_id) REFERENCES waydowntown.incarnations(id);


--
-- Name: games games_winner_answer_id_fkey; Type: FK CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.games
    ADD CONSTRAINT games_winner_answer_id_fkey FOREIGN KEY (winner_answer_id) REFERENCES waydowntown.answers(id) ON DELETE SET NULL;


--
-- Name: incarnations incarnations_region_id_fkey; Type: FK CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.incarnations
    ADD CONSTRAINT incarnations_region_id_fkey FOREIGN KEY (region_id) REFERENCES waydowntown.regions(id) ON DELETE SET NULL;


--
-- Name: regions regions_parent_id_fkey; Type: FK CONSTRAINT; Schema: waydowntown; Owner: -
--

ALTER TABLE ONLY waydowntown.regions
    ADD CONSTRAINT regions_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES waydowntown.regions(id) ON DELETE SET NULL;


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
INSERT INTO public."schema_migrations" (version) VALUES (20231111171443);
INSERT INTO public."schema_migrations" (version) VALUES (20231112020314);
INSERT INTO public."schema_migrations" (version) VALUES (20231204001556);
INSERT INTO public."schema_migrations" (version) VALUES (20231205235352);
INSERT INTO public."schema_migrations" (version) VALUES (20231217183904);
INSERT INTO public."schema_migrations" (version) VALUES (20231220025457);
INSERT INTO public."schema_migrations" (version) VALUES (20240630162659);
INSERT INTO public."schema_migrations" (version) VALUES (20240630162710);
INSERT INTO public."schema_migrations" (version) VALUES (20240630162715);
INSERT INTO public."schema_migrations" (version) VALUES (20240703014400);
INSERT INTO public."schema_migrations" (version) VALUES (20240703235731);
INSERT INTO public."schema_migrations" (version) VALUES (20240714173901);
INSERT INTO public."schema_migrations" (version) VALUES (20240721040506);
INSERT INTO public."schema_migrations" (version) VALUES (20240722224559);
INSERT INTO public."schema_migrations" (version) VALUES (20240723045728);
INSERT INTO public."schema_migrations" (version) VALUES (20240806025935);
INSERT INTO public."schema_migrations" (version) VALUES (20240806031811);
INSERT INTO public."schema_migrations" (version) VALUES (20240824211544);
INSERT INTO public."schema_migrations" (version) VALUES (20240825045118);
INSERT INTO public."schema_migrations" (version) VALUES (20240828005430);
INSERT INTO public."schema_migrations" (version) VALUES (20240831183915);
