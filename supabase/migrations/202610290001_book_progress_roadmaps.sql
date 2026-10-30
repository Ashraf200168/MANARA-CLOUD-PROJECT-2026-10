alter table public.exams
  add column if not exists roadmap_position integer,
  add column if not exists is_book_final boolean not null default false;

with ranked as (
  select
    id,
    row_number() over (
      partition by book_id
      order by created_at, id
    )::integer as position
  from public.exams
  where book_id is not null
)
update public.exams as exams
set roadmap_position = ranked.position
from ranked
where exams.id = ranked.id
  and exams.roadmap_position is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'exams_roadmap_position_positive'
      and conrelid = 'public.exams'::regclass
  ) then
    alter table public.exams
      add constraint exams_roadmap_position_positive
      check (roadmap_position is null or roadmap_position > 0);
  end if;
end
$$;

create index if not exists exams_book_roadmap_idx
  on public.exams (book_id, roadmap_position, id)
  where book_id is not null;

comment on column public.exams.roadmap_position is
  'Order of this exam in its book learning roadmap.';

comment on column public.exams.is_book_final is
  'Whether this exam is the final milestone for its book.';

-- Selecting a new final exam replaces the previous marker for that book.
create or replace function public.manara_set_book_final()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.book_id is null then
    new.is_book_final := false;
    new.roadmap_position := null;
  elsif new.is_book_final then
    perform id from public.books where id = new.book_id for update;
    update public.exams
      set is_book_final = false
      where book_id = new.book_id
        and id is distinct from new.id
        and is_book_final;
  end if;
  return new;
end;
$$;

drop trigger if exists manara_book_final on public.exams;
create trigger manara_book_final
  before insert or update of book_id, is_book_final on public.exams
  for each row execute function public.manara_set_book_final();
