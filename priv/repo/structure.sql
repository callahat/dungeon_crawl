--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;

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
-- Name: dungeon_map_tiles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    state character varying(255)
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
-- Name: dungeons; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.dungeons (
    id bigint NOT NULL,
    name character varying(255),
    width integer,
    height integer,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    autogenerated boolean,
    version integer DEFAULT 1,
    active boolean,
    deleted_at timestamp without time zone,
    previous_version_id bigint,
    user_id bigint
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
-- Name: map_instances; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.map_instances (
    id bigint NOT NULL,
    name character varying(255),
    width integer,
    height integer,
    map_id bigint,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
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
-- Name: map_tile_instances; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.map_tile_instances (
    id bigint NOT NULL,
    "row" integer,
    col integer,
    z_index integer,
    map_instance_id bigint,
    tile_template_id bigint,
    "character" character varying(255),
    color character varying(255),
    background_color character varying(255),
    state character varying(255)
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
-- Name: player_locations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp without time zone
);


--
-- Name: tile_templates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.tile_templates (
    id bigint NOT NULL,
    name character varying(255),
    "character" character varying(255),
    description character varying(255),
    color character varying(255),
    background_color character varying(255),
    responders character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    user_id bigint,
    version integer DEFAULT 1,
    active boolean,
    public boolean,
    previous_version_id bigint,
    state character varying(255)
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
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying(255),
    username character varying(255) NOT NULL,
    password_hash character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_admin boolean DEFAULT false,
    user_id_hash character varying(255)
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
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_map_tiles ALTER COLUMN id SET DEFAULT nextval('public.dungeon_map_tiles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons ALTER COLUMN id SET DEFAULT nextval('public.dungeons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_instances ALTER COLUMN id SET DEFAULT nextval('public.map_instances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_tile_instances ALTER COLUMN id SET DEFAULT nextval('public.map_tile_instances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations ALTER COLUMN id SET DEFAULT nextval('public.player_locations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates ALTER COLUMN id SET DEFAULT nextval('public.tile_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: dungeon_map_tiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.dungeon_map_tiles
    ADD CONSTRAINT dungeon_map_tiles_pkey PRIMARY KEY (id);


--
-- Name: dungeons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_pkey PRIMARY KEY (id);


--
-- Name: map_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.map_instances
    ADD CONSTRAINT map_instances_pkey PRIMARY KEY (id);


--
-- Name: map_tile_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.map_tile_instances
    ADD CONSTRAINT map_tile_instances_pkey PRIMARY KEY (id);


--
-- Name: player_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.player_locations
    ADD CONSTRAINT player_locations_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tile_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.tile_templates
    ADD CONSTRAINT tile_templates_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: dungeon_map_tiles_dungeon_id_row_col_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dungeon_map_tiles_dungeon_id_row_col_index ON public.dungeon_map_tiles USING btree (dungeon_id, "row", col);


--
-- Name: dungeon_map_tiles_tile_template_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dungeon_map_tiles_tile_template_id_index ON public.dungeon_map_tiles USING btree (tile_template_id);


--
-- Name: dungeons_active_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dungeons_active_index ON public.dungeons USING btree (active);


--
-- Name: dungeons_deleted_at_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dungeons_deleted_at_index ON public.dungeons USING btree (deleted_at);


--
-- Name: dungeons_user_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX dungeons_user_id_index ON public.dungeons USING btree (user_id);


--
-- Name: map_instances_map_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX map_instances_map_id_index ON public.map_instances USING btree (map_id);


--
-- Name: map_tile_instances_map_instance_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX map_tile_instances_map_instance_id_index ON public.map_tile_instances USING btree (map_instance_id);


--
-- Name: map_tile_instances_tile_template_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX map_tile_instances_tile_template_id_index ON public.map_tile_instances USING btree (tile_template_id);


--
-- Name: player_locations_map_tile_instance_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX player_locations_map_tile_instance_id_index ON public.player_locations USING btree (map_tile_instance_id);


--
-- Name: player_locations_user_id_hash_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX player_locations_user_id_hash_index ON public.player_locations USING btree (user_id_hash);


--
-- Name: tile_templates_active_public_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX tile_templates_active_public_index ON public.tile_templates USING btree (active, public);


--
-- Name: tile_templates_deleted_at_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX tile_templates_deleted_at_index ON public.tile_templates USING btree (deleted_at);


--
-- Name: tile_templates_user_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX tile_templates_user_id_index ON public.tile_templates USING btree (user_id);


--
-- Name: users_user_id_hash_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX users_user_id_hash_index ON public.users USING btree (user_id_hash);


--
-- Name: users_username_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX users_username_index ON public.users USING btree (username);


--
-- Name: dungeon_map_tiles_dungeon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_map_tiles
    ADD CONSTRAINT dungeon_map_tiles_dungeon_id_fkey FOREIGN KEY (dungeon_id) REFERENCES public.dungeons(id);


--
-- Name: dungeon_map_tiles_tile_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeon_map_tiles
    ADD CONSTRAINT dungeon_map_tiles_tile_template_id_fkey FOREIGN KEY (tile_template_id) REFERENCES public.tile_templates(id);


--
-- Name: dungeons_previous_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_previous_version_id_fkey FOREIGN KEY (previous_version_id) REFERENCES public.dungeons(id) ON DELETE CASCADE;


--
-- Name: dungeons_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dungeons
    ADD CONSTRAINT dungeons_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: map_instances_map_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_instances
    ADD CONSTRAINT map_instances_map_id_fkey FOREIGN KEY (map_id) REFERENCES public.dungeons(id) ON DELETE CASCADE;


--
-- Name: map_tile_instances_map_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_tile_instances
    ADD CONSTRAINT map_tile_instances_map_instance_id_fkey FOREIGN KEY (map_instance_id) REFERENCES public.map_instances(id) ON DELETE CASCADE;


--
-- Name: map_tile_instances_tile_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_tile_instances
    ADD CONSTRAINT map_tile_instances_tile_template_id_fkey FOREIGN KEY (tile_template_id) REFERENCES public.tile_templates(id) ON DELETE CASCADE;


--
-- Name: player_locations_map_tile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations
    ADD CONSTRAINT player_locations_map_tile_id_fkey FOREIGN KEY (map_tile_id) REFERENCES public.dungeon_map_tiles(id) ON DELETE CASCADE;


--
-- Name: player_locations_map_tile_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.player_locations
    ADD CONSTRAINT player_locations_map_tile_instance_id_fkey FOREIGN KEY (map_tile_instance_id) REFERENCES public.map_tile_instances(id) ON DELETE CASCADE;


--
-- Name: tile_templates_previous_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates
    ADD CONSTRAINT tile_templates_previous_version_id_fkey FOREIGN KEY (previous_version_id) REFERENCES public.tile_templates(id) ON DELETE CASCADE;


--
-- Name: tile_templates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tile_templates
    ADD CONSTRAINT tile_templates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20190324205201), (20190330204745), (20190402223857), (20190402225536), (20190413175151), (20190414160056), (20190419001231), (20190527233310), (20190609142636), (20190609171130), (20190612023436), (20190612023457), (20190615154923), (20190616233716), (20190622001716), (20190622003151), (20190622003218), (20190622010437), (20190629130917), (20190630174337), (20190806015637), (20190819020358), (20190825172537);

