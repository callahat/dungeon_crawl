--
-- PostgreSQL database dump
--

-- Dumped from database version 10.17 (Ubuntu 10.17-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 10.17 (Ubuntu 10.17-0ubuntu0.18.04.1)

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
-- Name: dungeon_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dungeon_instances (
    id bigint NOT NULL,
    name character varying(255),
    autogenerated boolean,
    state character varying(255),
    dungeon_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    passcode character varying(8),
    is_private boolean
);


--
-- Name: dungeon_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dungeon_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dungeon_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dungeon_instances_id_seq OWNED BY public.dungeon_instances.id;


--
-- Name: dungeons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dungeons (
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
    default_map_height integer,
    line_identifier integer,
    title_number integer,
    description character varying(1024)
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
-- Name: effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.effects (
    id bigint NOT NULL,
    name character varying(32),
    slug character varying(45),
    zzfx_params character varying(120),
    public boolean DEFAULT false NOT NULL,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: effects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.effects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.effects_id_seq OWNED BY public.effects.id;


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id bigint NOT NULL,
    name character varying(32),
    description character varying(255),
    slug character varying(255),
    script character varying(2048),
    public boolean DEFAULT false NOT NULL,
    weapon boolean DEFAULT false NOT NULL,
    consumable boolean DEFAULT false NOT NULL,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.items_id_seq OWNED BY public.items.id;


--
-- Name: level_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.level_instances (
    id bigint NOT NULL,
    name character varying(255),
    width integer,
    height integer,
    level_id bigint,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    state character varying(255),
    dungeon_instance_id bigint,
    number integer,
    entrance boolean,
    number_north integer,
    number_south integer,
    number_east integer,
    number_west integer
);


--
-- Name: level_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.level_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: level_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.level_instances_id_seq OWNED BY public.level_instances.id;


--
-- Name: levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.levels (
    id bigint NOT NULL,
    name character varying(255),
    width integer,
    height integer,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    max_instances integer,
    state character varying(255),
    dungeon_id bigint,
    number integer,
    entrance boolean,
    number_north integer,
    number_south integer,
    number_east integer,
    number_west integer
);


--
-- Name: levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.levels_id_seq OWNED BY public.levels.id;


--
-- Name: player_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.player_locations (
    id bigint NOT NULL,
    user_id_hash character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    tile_instance_id bigint
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
-- Name: scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scores (
    id bigint NOT NULL,
    score integer,
    steps integer,
    result character varying(255),
    victory boolean DEFAULT false NOT NULL,
    dungeon_id bigint,
    user_id_hash character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    duration integer,
    deaths integer
);


--
-- Name: scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scores_id_seq OWNED BY public.scores.id;


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
    level_id bigint
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
-- Name: tile_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tile_instances (
    id bigint NOT NULL,
    "row" integer,
    col integer,
    z_index integer,
    level_instance_id bigint,
    "character" character varying(255),
    color character varying(255),
    background_color character varying(255),
    state character varying(2048),
    script character varying(2048),
    name character varying(32),
    animate_random boolean,
    animate_colors character varying(255),
    animate_background_colors character varying(255),
    animate_characters character varying(32),
    animate_period integer
);


--
-- Name: tile_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tile_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tile_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tile_instances_id_seq OWNED BY public.tile_instances.id;


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
-- Name: tiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tiles (
    id bigint NOT NULL,
    "row" integer,
    col integer,
    level_id bigint,
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
-- Name: tiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tiles_id_seq OWNED BY public.tiles.id;


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
-- Name: dungeon_instances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_instances ALTER COLUMN id SET DEFAULT nextval('public.dungeon_instances_id_seq'::regclass);


--
-- Name: dungeons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons ALTER COLUMN id SET DEFAULT nextval('public.dungeons_id_seq'::regclass);


--
-- Name: effects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effects ALTER COLUMN id SET DEFAULT nextval('public.effects_id_seq'::regclass);


--
-- Name: items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items ALTER COLUMN id SET DEFAULT nextval('public.items_id_seq'::regclass);


--
-- Name: level_instances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_instances ALTER COLUMN id SET DEFAULT nextval('public.level_instances_id_seq'::regclass);


--
-- Name: levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.levels ALTER COLUMN id SET DEFAULT nextval('public.levels_id_seq'::regclass);


--
-- Name: player_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations ALTER COLUMN id SET DEFAULT nextval('public.player_locations_id_seq'::regclass);


--
-- Name: scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scores ALTER COLUMN id SET DEFAULT nextval('public.scores_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: spawn_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spawn_locations ALTER COLUMN id SET DEFAULT nextval('public.spawn_locations_id_seq'::regclass);


--
-- Name: tile_instances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_instances ALTER COLUMN id SET DEFAULT nextval('public.tile_instances_id_seq'::regclass);


--
-- Name: tile_shortlists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_shortlists ALTER COLUMN id SET DEFAULT nextval('public.tile_shortlists_id_seq'::regclass);


--
-- Name: tile_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates ALTER COLUMN id SET DEFAULT nextval('public.tile_templates_id_seq'::regclass);


--
-- Name: tiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiles ALTER COLUMN id SET DEFAULT nextval('public.tiles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: dungeon_instances dungeon_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_instances
    ADD CONSTRAINT dungeon_instances_pkey PRIMARY KEY (id);


--
-- Name: dungeons dungeons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_pkey PRIMARY KEY (id);


--
-- Name: effects effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effects
    ADD CONSTRAINT effects_pkey PRIMARY KEY (id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: level_instances level_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_instances
    ADD CONSTRAINT level_instances_pkey PRIMARY KEY (id);


--
-- Name: levels levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.levels
    ADD CONSTRAINT levels_pkey PRIMARY KEY (id);


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
-- Name: scores scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_pkey PRIMARY KEY (id);


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
-- Name: tile_instances tile_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_instances
    ADD CONSTRAINT tile_instances_pkey PRIMARY KEY (id);


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
-- Name: tiles tiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiles
    ADD CONSTRAINT tiles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: dungeons_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dungeons_active_index ON public.dungeons USING btree (active);


--
-- Name: dungeons_deleted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dungeons_deleted_at_index ON public.dungeons USING btree (deleted_at);


--
-- Name: dungeons_line_identifier_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dungeons_line_identifier_index ON public.dungeons USING btree (line_identifier);


--
-- Name: effects_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX effects_slug_index ON public.effects USING btree (slug);


--
-- Name: effects_user_id_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX effects_user_id_slug_index ON public.effects USING btree (user_id, slug);


--
-- Name: items_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX items_slug_index ON public.items USING btree (slug);


--
-- Name: items_user_id_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX items_user_id_slug_index ON public.items USING btree (user_id, slug);


--
-- Name: level_instances_dungeon_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX level_instances_dungeon_instance_id_index ON public.level_instances USING btree (dungeon_instance_id);


--
-- Name: level_instances_dungeon_instance_id_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX level_instances_dungeon_instance_id_number_index ON public.level_instances USING btree (dungeon_instance_id, number);


--
-- Name: level_instances_level_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX level_instances_level_id_index ON public.level_instances USING btree (level_id);


--
-- Name: levels_dungeon_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX levels_dungeon_id_index ON public.levels USING btree (dungeon_id);


--
-- Name: levels_dungeon_id_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX levels_dungeon_id_number_index ON public.levels USING btree (dungeon_id, number);


--
-- Name: player_locations_tile_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX player_locations_tile_instance_id_index ON public.player_locations USING btree (tile_instance_id);


--
-- Name: player_locations_user_id_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX player_locations_user_id_hash_index ON public.player_locations USING btree (user_id_hash);


--
-- Name: scores_dungeon_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX scores_dungeon_id_index ON public.scores USING btree (dungeon_id);


--
-- Name: scores_user_id_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX scores_user_id_hash_index ON public.scores USING btree (user_id_hash);


--
-- Name: spawn_locations_level_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX spawn_locations_level_id_index ON public.spawn_locations USING btree (level_id);


--
-- Name: spawn_locations_level_id_row_col_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX spawn_locations_level_id_row_col_index ON public.spawn_locations USING btree (level_id, "row", col);


--
-- Name: tile_instances_level_instance_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tile_instances_level_instance_id_index ON public.tile_instances USING btree (level_instance_id);


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
-- Name: tiles_level_id_row_col_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tiles_level_id_row_col_index ON public.tiles USING btree (level_id, "row", col);


--
-- Name: tiles_tile_template_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tiles_tile_template_id_index ON public.tiles USING btree (tile_template_id);


--
-- Name: users_user_id_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_user_id_hash_index ON public.users USING btree (user_id_hash);


--
-- Name: users_username_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_index ON public.users USING btree (username);


--
-- Name: dungeon_instances dungeon_instances_dungeon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_instances
    ADD CONSTRAINT dungeon_instances_dungeon_id_fkey FOREIGN KEY (dungeon_id) REFERENCES public.dungeons(id) ON DELETE CASCADE;


--
-- Name: dungeons dungeons_previous_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_previous_version_id_fkey FOREIGN KEY (previous_version_id) REFERENCES public.dungeons(id) ON DELETE CASCADE;


--
-- Name: dungeons dungeons_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: effects effects_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effects
    ADD CONSTRAINT effects_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: items items_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: level_instances level_instances_dungeon_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_instances
    ADD CONSTRAINT level_instances_dungeon_instance_id_fkey FOREIGN KEY (dungeon_instance_id) REFERENCES public.dungeon_instances(id) ON DELETE CASCADE;


--
-- Name: level_instances level_instances_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_instances
    ADD CONSTRAINT level_instances_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.levels(id) ON DELETE CASCADE;


--
-- Name: levels levels_dungeon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.levels
    ADD CONSTRAINT levels_dungeon_id_fkey FOREIGN KEY (dungeon_id) REFERENCES public.dungeons(id) ON DELETE CASCADE;


--
-- Name: player_locations player_locations_tile_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations
    ADD CONSTRAINT player_locations_tile_instance_id_fkey FOREIGN KEY (tile_instance_id) REFERENCES public.tile_instances(id) ON DELETE CASCADE;


--
-- Name: scores scores_dungeon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_dungeon_id_fkey FOREIGN KEY (dungeon_id) REFERENCES public.dungeons(id);


--
-- Name: spawn_locations spawn_locations_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spawn_locations
    ADD CONSTRAINT spawn_locations_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.levels(id);


--
-- Name: tile_instances tile_instances_level_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_instances
    ADD CONSTRAINT tile_instances_level_instance_id_fkey FOREIGN KEY (level_instance_id) REFERENCES public.level_instances(id) ON DELETE CASCADE;


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
-- Name: tiles tiles_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiles
    ADD CONSTRAINT tiles_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.levels(id);


--
-- Name: tiles tiles_tile_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiles
    ADD CONSTRAINT tiles_tile_template_id_fkey FOREIGN KEY (tile_template_id) REFERENCES public.tile_templates(id);


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20190324205201);
INSERT INTO public."schema_migrations" (version) VALUES (20190330204745);
INSERT INTO public."schema_migrations" (version) VALUES (20190402223857);
INSERT INTO public."schema_migrations" (version) VALUES (20190402225536);
INSERT INTO public."schema_migrations" (version) VALUES (20190413175151);
INSERT INTO public."schema_migrations" (version) VALUES (20190414160056);
INSERT INTO public."schema_migrations" (version) VALUES (20190419001231);
INSERT INTO public."schema_migrations" (version) VALUES (20190527233310);
INSERT INTO public."schema_migrations" (version) VALUES (20190609142636);
INSERT INTO public."schema_migrations" (version) VALUES (20190609171130);
INSERT INTO public."schema_migrations" (version) VALUES (20190612023436);
INSERT INTO public."schema_migrations" (version) VALUES (20190612023457);
INSERT INTO public."schema_migrations" (version) VALUES (20190615154923);
INSERT INTO public."schema_migrations" (version) VALUES (20190616233716);
INSERT INTO public."schema_migrations" (version) VALUES (20190622001716);
INSERT INTO public."schema_migrations" (version) VALUES (20190622003151);
INSERT INTO public."schema_migrations" (version) VALUES (20190622003218);
INSERT INTO public."schema_migrations" (version) VALUES (20190622010437);
INSERT INTO public."schema_migrations" (version) VALUES (20190629130917);
INSERT INTO public."schema_migrations" (version) VALUES (20190630174337);
INSERT INTO public."schema_migrations" (version) VALUES (20190806015637);
INSERT INTO public."schema_migrations" (version) VALUES (20190819020358);
INSERT INTO public."schema_migrations" (version) VALUES (20190825172537);
INSERT INTO public."schema_migrations" (version) VALUES (20190827000819);
INSERT INTO public."schema_migrations" (version) VALUES (20190918120207);
INSERT INTO public."schema_migrations" (version) VALUES (20200310031404);
INSERT INTO public."schema_migrations" (version) VALUES (20200310040856);
INSERT INTO public."schema_migrations" (version) VALUES (20200321024143);
INSERT INTO public."schema_migrations" (version) VALUES (20200510030351);
INSERT INTO public."schema_migrations" (version) VALUES (20200523211657);
INSERT INTO public."schema_migrations" (version) VALUES (20200806010421);
INSERT INTO public."schema_migrations" (version) VALUES (20200909021208);
INSERT INTO public."schema_migrations" (version) VALUES (20200921024551);
INSERT INTO public."schema_migrations" (version) VALUES (20201005015458);
INSERT INTO public."schema_migrations" (version) VALUES (20201028012821);
INSERT INTO public."schema_migrations" (version) VALUES (20201108145214);
INSERT INTO public."schema_migrations" (version) VALUES (20201108191414);
INSERT INTO public."schema_migrations" (version) VALUES (20201117224347);
INSERT INTO public."schema_migrations" (version) VALUES (20201204023727);
INSERT INTO public."schema_migrations" (version) VALUES (20201205171203);
INSERT INTO public."schema_migrations" (version) VALUES (20201215004936);
INSERT INTO public."schema_migrations" (version) VALUES (20210208023219);
INSERT INTO public."schema_migrations" (version) VALUES (20210304032345);
INSERT INTO public."schema_migrations" (version) VALUES (20210417230808);
INSERT INTO public."schema_migrations" (version) VALUES (20210418205012);
INSERT INTO public."schema_migrations" (version) VALUES (20210423205519);
INSERT INTO public."schema_migrations" (version) VALUES (20210425170715);
INSERT INTO public."schema_migrations" (version) VALUES (20210503022021);
INSERT INTO public."schema_migrations" (version) VALUES (20210513224613);
INSERT INTO public."schema_migrations" (version) VALUES (20210515021252);
INSERT INTO public."schema_migrations" (version) VALUES (20210605224807);
INSERT INTO public."schema_migrations" (version) VALUES (20210612225130);
INSERT INTO public."schema_migrations" (version) VALUES (20210613021818);
INSERT INTO public."schema_migrations" (version) VALUES (20211009194149);
INSERT INTO public."schema_migrations" (version) VALUES (20211220033222);
INSERT INTO public."schema_migrations" (version) VALUES (20211230042239);
