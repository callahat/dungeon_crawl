--
-- PostgreSQL database dump
--

-- Dumped from database version 10.15 (Ubuntu 10.15-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 10.15 (Ubuntu 10.15-0ubuntu0.18.04.1)

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
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: dungeon_map_tiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dungeon_map_tiles (
    id bigint NOT NULL,
    "row" integer,
    col integer,
    dungeon_id bigint,
    tile_template_id bigint,
    z_index integer,
    "character" character varying(255),
    color character varying(255),
    background_color character varying(255),
    state character varying(255),
    script character varying(2048),
    name character varying(32),
    animate_random boolean,
    animate_colors character varying(255),
    animate_background_colors character varying(255),
    animate_characters character varying(32),
    animate_period integer
);


--
-- Name: dungeon_map_tiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dungeon_map_tiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dungeon_map_tiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dungeon_map_tiles_id_seq OWNED BY public.dungeon_map_tiles.id;


--
-- Name: dungeons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dungeons (
    id bigint NOT NULL,
    name character varying(255),
    width integer,
    height integer,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    max_instances integer,
    state character varying(255),
    map_set_id bigint,
    number integer,
    entrance boolean,
    number_north integer,
    number_south integer,
    number_east integer,
    number_west integer
);


--
-- Name: dungeons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dungeons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dungeons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dungeons_id_seq OWNED BY public.dungeons.id;


--
-- Name: map_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_instances (
    id bigint NOT NULL,
    name character varying(255),
    width integer,
    height integer,
    map_id bigint,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    state character varying(255),
    map_set_instance_id bigint,
    number integer,
    entrance boolean,
    number_north integer,
    number_south integer,
    number_east integer,
    number_west integer
);


--
-- Name: map_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.map_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: map_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.map_instances_id_seq OWNED BY public.map_instances.id;


--
-- Name: map_set_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_set_instances (
    id bigint NOT NULL,
    name character varying(255),
    autogenerated boolean,
    state character varying(255),
    map_set_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    passcode character varying(8),
    is_private boolean
);


--
-- Name: map_set_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.map_set_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: map_set_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.map_set_instances_id_seq OWNED BY public.map_set_instances.id;


--
-- Name: map_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_sets (
    id bigint NOT NULL,
    name character varying(255),
    autogenerated boolean,
    state character varying(255),
    active boolean,
    version integer,
    deleted_at timestamp(0) without time zone,
    previous_version_id bigint,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    default_map_width integer,
    default_map_height integer
);


--
-- Name: map_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.map_sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: map_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.map_sets_id_seq OWNED BY public.map_sets.id;


--
-- Name: map_tile_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_tile_instances (
    id bigint NOT NULL,
    "row" integer,
    col integer,
    z_index integer,
    map_instance_id bigint,
    "character" character varying(255),
    color character varying(255),
    background_color character varying(255),
    state character varying(255),
    script character varying(2048),
    name character varying(32),
    animate_random boolean,
    animate_colors character varying(255),
    animate_background_colors character varying(255),
    animate_characters character varying(32),
    animate_period integer
);


--
-- Name: map_tile_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.map_tile_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: map_tile_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.map_tile_instances_id_seq OWNED BY public.map_tile_instances.id;


--
-- Name: player_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.player_locations (
    id bigint NOT NULL,
    user_id_hash character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    map_tile_id bigint,
    map_tile_instance_id bigint
);


--
-- Name: player_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.player_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: player_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.player_locations_id_seq OWNED BY public.player_locations.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp without time zone
);


--
-- Name: settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settings (
    id bigint NOT NULL,
    max_height integer,
    max_width integer,
    autogen_height integer,
    autogen_width integer,
    max_instances integer,
    autogen_solo_enabled boolean DEFAULT false NOT NULL,
    non_admin_dungeons_enabled boolean DEFAULT false NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    full_rerender_threshold integer
);


--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.settings_id_seq OWNED BY public.settings.id;


--
-- Name: spawn_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spawn_locations (
    id bigint NOT NULL,
    "row" integer,
    col integer,
    dungeon_id bigint
);


--
-- Name: spawn_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spawn_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spawn_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spawn_locations_id_seq OWNED BY public.spawn_locations.id;


--
-- Name: tile_shortlists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tile_shortlists (
    id bigint NOT NULL,
    user_id bigint,
    tile_template_id bigint,
    name character varying(255),
    "character" character varying(255),
    description character varying(255),
    color character varying(255),
    background_color character varying(255),
    script character varying(2048),
    state character varying(255),
    slug character varying(255),
    animate_random boolean,
    animate_colors character varying(255),
    animate_background_colors character varying(255),
    animate_characters character varying(32),
    animate_period integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tile_shortlists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tile_shortlists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tile_shortlists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tile_shortlists_id_seq OWNED BY public.tile_shortlists.id;


--
-- Name: tile_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tile_templates (
    id bigint NOT NULL,
    name character varying(255),
    "character" character varying(255),
    description character varying(255),
    color character varying(255),
    background_color character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    user_id bigint,
    version integer DEFAULT 1,
    active boolean,
    public boolean,
    previous_version_id bigint,
    state character varying(255),
    script character varying(2048),
    slug character varying(255),
    animate_random boolean,
    animate_colors character varying(255),
    animate_background_colors character varying(255),
    animate_characters character varying(32),
    animate_period integer,
    group_name character varying(16)
);


--
-- Name: tile_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tile_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tile_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tile_templates_id_seq OWNED BY public.tile_templates.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying(255),
    username character varying(255) NOT NULL,
    password_hash character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_admin boolean DEFAULT false,
    user_id_hash character varying(255),
    color character varying(255),
    background_color character varying(255)
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: dungeon_map_tiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_map_tiles ALTER COLUMN id SET DEFAULT nextval('public.dungeon_map_tiles_id_seq'::regclass);


--
-- Name: dungeons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons ALTER COLUMN id SET DEFAULT nextval('public.dungeons_id_seq'::regclass);


--
-- Name: map_instances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_instances ALTER COLUMN id SET DEFAULT nextval('public.map_instances_id_seq'::regclass);


--
-- Name: map_set_instances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_set_instances ALTER COLUMN id SET DEFAULT nextval('public.map_set_instances_id_seq'::regclass);


--
-- Name: map_sets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_sets ALTER COLUMN id SET DEFAULT nextval('public.map_sets_id_seq'::regclass);


--
-- Name: map_tile_instances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_tile_instances ALTER COLUMN id SET DEFAULT nextval('public.map_tile_instances_id_seq'::regclass);


--
-- Name: player_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations ALTER COLUMN id SET DEFAULT nextval('public.player_locations_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: spawn_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spawn_locations ALTER COLUMN id SET DEFAULT nextval('public.spawn_locations_id_seq'::regclass);


--
-- Name: tile_shortlists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_shortlists ALTER COLUMN id SET DEFAULT nextval('public.tile_shortlists_id_seq'::regclass);


--
-- Name: tile_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates ALTER COLUMN id SET DEFAULT nextval('public.tile_templates_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: dungeon_map_tiles dungeon_map_tiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_map_tiles
    ADD CONSTRAINT dungeon_map_tiles_pkey PRIMARY KEY (id);


--
-- Name: dungeons dungeons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_pkey PRIMARY KEY (id);


--
-- Name: map_instances map_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_instances
    ADD CONSTRAINT map_instances_pkey PRIMARY KEY (id);


--
-- Name: map_set_instances map_set_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_set_instances
    ADD CONSTRAINT map_set_instances_pkey PRIMARY KEY (id);


--
-- Name: map_sets map_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_sets
    ADD CONSTRAINT map_sets_pkey PRIMARY KEY (id);


--
-- Name: map_tile_instances map_tile_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_tile_instances
    ADD CONSTRAINT map_tile_instances_pkey PRIMARY KEY (id);


--
-- Name: player_locations player_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations
    ADD CONSTRAINT player_locations_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: spawn_locations spawn_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spawn_locations
    ADD CONSTRAINT spawn_locations_pkey PRIMARY KEY (id);


--
-- Name: tile_shortlists tile_shortlists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_shortlists
    ADD CONSTRAINT tile_shortlists_pkey PRIMARY KEY (id);


--
-- Name: tile_templates tile_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates
    ADD CONSTRAINT tile_templates_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: dungeon_map_tiles_dungeon_id_row_col_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dungeon_map_tiles_dungeon_id_row_col_index ON public.dungeon_map_tiles USING btree (dungeon_id, "row", col);


--
-- Name: dungeon_map_tiles_tile_template_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dungeon_map_tiles_tile_template_id_index ON public.dungeon_map_tiles USING btree (tile_template_id);


--
-- Name: dungeons_map_set_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dungeons_map_set_id_index ON public.dungeons USING btree (map_set_id);


--
-- Name: dungeons_map_set_id_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX dungeons_map_set_id_number_index ON public.dungeons USING btree (map_set_id, number);


--
-- Name: map_instances_map_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX map_instances_map_id_index ON public.map_instances USING btree (map_id);


--
-- Name: map_instances_map_set_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX map_instances_map_set_instance_id_index ON public.map_instances USING btree (map_set_instance_id);


--
-- Name: map_instances_map_set_instance_id_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX map_instances_map_set_instance_id_number_index ON public.map_instances USING btree (map_set_instance_id, number);


--
-- Name: map_sets_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX map_sets_active_index ON public.map_sets USING btree (active);


--
-- Name: map_sets_deleted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX map_sets_deleted_at_index ON public.map_sets USING btree (deleted_at);


--
-- Name: map_tile_instances_map_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX map_tile_instances_map_instance_id_index ON public.map_tile_instances USING btree (map_instance_id);


--
-- Name: player_locations_map_tile_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX player_locations_map_tile_instance_id_index ON public.player_locations USING btree (map_tile_instance_id);


--
-- Name: player_locations_user_id_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX player_locations_user_id_hash_index ON public.player_locations USING btree (user_id_hash);


--
-- Name: spawn_locations_dungeon_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX spawn_locations_dungeon_id_index ON public.spawn_locations USING btree (dungeon_id);


--
-- Name: spawn_locations_dungeon_id_row_col_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX spawn_locations_dungeon_id_row_col_index ON public.spawn_locations USING btree (dungeon_id, "row", col);


--
-- Name: tile_shortlists_tile_template_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_shortlists_tile_template_id_index ON public.tile_shortlists USING btree (tile_template_id);


--
-- Name: tile_shortlists_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_shortlists_user_id_index ON public.tile_shortlists USING btree (user_id);


--
-- Name: tile_templates_active_public_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_templates_active_public_index ON public.tile_templates USING btree (active, public);


--
-- Name: tile_templates_deleted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_templates_deleted_at_index ON public.tile_templates USING btree (deleted_at);


--
-- Name: tile_templates_group_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_templates_group_name_index ON public.tile_templates USING btree (group_name);


--
-- Name: tile_templates_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_templates_slug_index ON public.tile_templates USING btree (slug);


--
-- Name: tile_templates_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_templates_user_id_index ON public.tile_templates USING btree (user_id);


--
-- Name: users_user_id_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_user_id_hash_index ON public.users USING btree (user_id_hash);


--
-- Name: users_username_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_index ON public.users USING btree (username);


--
-- Name: dungeon_map_tiles dungeon_map_tiles_dungeon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_map_tiles
    ADD CONSTRAINT dungeon_map_tiles_dungeon_id_fkey FOREIGN KEY (dungeon_id) REFERENCES public.dungeons(id);


--
-- Name: dungeon_map_tiles dungeon_map_tiles_tile_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_map_tiles
    ADD CONSTRAINT dungeon_map_tiles_tile_template_id_fkey FOREIGN KEY (tile_template_id) REFERENCES public.tile_templates(id);


--
-- Name: dungeons dungeons_map_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_map_set_id_fkey FOREIGN KEY (map_set_id) REFERENCES public.map_sets(id) ON DELETE CASCADE;


--
-- Name: map_instances map_instances_map_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_instances
    ADD CONSTRAINT map_instances_map_id_fkey FOREIGN KEY (map_id) REFERENCES public.dungeons(id) ON DELETE CASCADE;


--
-- Name: map_instances map_instances_map_set_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_instances
    ADD CONSTRAINT map_instances_map_set_instance_id_fkey FOREIGN KEY (map_set_instance_id) REFERENCES public.map_set_instances(id) ON DELETE CASCADE;


--
-- Name: map_set_instances map_set_instances_map_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_set_instances
    ADD CONSTRAINT map_set_instances_map_set_id_fkey FOREIGN KEY (map_set_id) REFERENCES public.map_sets(id) ON DELETE CASCADE;


--
-- Name: map_sets map_sets_previous_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_sets
    ADD CONSTRAINT map_sets_previous_version_id_fkey FOREIGN KEY (previous_version_id) REFERENCES public.map_sets(id) ON DELETE CASCADE;


--
-- Name: map_sets map_sets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_sets
    ADD CONSTRAINT map_sets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: map_tile_instances map_tile_instances_map_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_tile_instances
    ADD CONSTRAINT map_tile_instances_map_instance_id_fkey FOREIGN KEY (map_instance_id) REFERENCES public.map_instances(id) ON DELETE CASCADE;


--
-- Name: player_locations player_locations_map_tile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations
    ADD CONSTRAINT player_locations_map_tile_id_fkey FOREIGN KEY (map_tile_id) REFERENCES public.dungeon_map_tiles(id) ON DELETE CASCADE;


--
-- Name: player_locations player_locations_map_tile_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations
    ADD CONSTRAINT player_locations_map_tile_instance_id_fkey FOREIGN KEY (map_tile_instance_id) REFERENCES public.map_tile_instances(id) ON DELETE CASCADE;


--
-- Name: spawn_locations spawn_locations_dungeon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spawn_locations
    ADD CONSTRAINT spawn_locations_dungeon_id_fkey FOREIGN KEY (dungeon_id) REFERENCES public.dungeons(id);


--
-- Name: tile_shortlists tile_shortlists_tile_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_shortlists
    ADD CONSTRAINT tile_shortlists_tile_template_id_fkey FOREIGN KEY (tile_template_id) REFERENCES public.tile_templates(id) ON DELETE CASCADE;


--
-- Name: tile_shortlists tile_shortlists_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_shortlists
    ADD CONSTRAINT tile_shortlists_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tile_templates tile_templates_previous_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates
    ADD CONSTRAINT tile_templates_previous_version_id_fkey FOREIGN KEY (previous_version_id) REFERENCES public.tile_templates(id) ON DELETE CASCADE;


--
-- Name: tile_templates tile_templates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates
    ADD CONSTRAINT tile_templates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20190324205201), (20190330204745), (20190402223857), (20190402225536), (20190413175151), (20190414160056), (20190419001231), (20190527233310), (20190609142636), (20190609171130), (20190612023436), (20190612023457), (20190615154923), (20190616233716), (20190622001716), (20190622003151), (20190622003218), (20190622010437), (20190629130917), (20190630174337), (20190806015637), (20190819020358), (20190825172537), (20190827000819), (20190918120207), (20200310031404), (20200310040856), (20200321024143), (20200510030351), (20200523211657), (20200806010421), (20200909021208), (20200921024551), (20201005015458), (20201028012821), (20201108145214), (20201108191414), (20201117224347), (20201204023727), (20201205171203), (20201215004936), (20210208023219), (20210304032345);

