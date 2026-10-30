import "app.q" as ap
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "testing.q" as t

struct Counter
  public n: int
  public ticks: int
  public last: string
  public cursor: array<int>
end

impl ap.Program for Counter
  public fun update(self, ev: Event, ctx: ap.Context)
    if ev.kind == "key" and ev.key == "+" then
      self.n += 1
    elseif ev.kind == "key" and ev.key == "q" then
      ctx.quit()
    elseif ev.kind == "key" and ev.key == "t" then
      ctx.every("clock", 1000)
    elseif ev.kind == "key" and ev.key == "o" then
      ctx.after("once", 500)
    elseif ev.kind == "key" and ev.key == "x" then
      ctx.cancel("clock")
    elseif ev.kind == "key" and ev.key == "T" then
      ctx.title("Counter {self.n}")
    elseif ev.kind == "key" and ev.key == "c" then
      self.cursor = [3, 1]
    elseif ev.kind == "timer" then
      self.ticks += 1
      self.last = ev.text
    end
  end

  public fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
    screen.put(1, 0, "n={self.n} ticks={self.ticks} {self.last}", st.Style.create())
    screen.put(1, 2, "{area.w}x{area.h}", st.Style.create())
    self.cursor
  end
end

fun counter() -> Counter
  Counter { n: 0, ticks: 0, last: "", cursor: [] }
end

fun test_the_first_picture_is_drawn_and_a_key_changes_it()
  let app = t.Harness.start(20, 4, counter())
  assert_eq(app.line(0), " n=0 ticks=0")
  app.key("+")
  app.key("+")
  assert(app.contains("n=2"))
  assert_eq(app.line(2), " 20x4")
end

fun test_only_what_changed_is_written()
  let app = t.Harness.start(20, 4, counter())
  let before = app.output().len()
  app.key("z")
  assert_eq(app.output().len(), before)
  app.key("+")
  assert_eq(app.output().len(), before + 1)
  assert(not app.output()[before].contains("20x4"))
end

fun test_q_quits_and_ctrl_c_quits_unless_kept()
  let app = t.Harness.start(20, 4, counter())
  assert(not app.finished())
  app.key("q")
  assert(app.finished())
  let other = t.Harness.start(20, 4, counter())
  other.ctrl("c")
  assert(other.finished())
end

fun test_a_repeating_timer_fires_when_time_goes_by()
  let app = t.Harness.start(30, 4, counter())
  app.key("t")
  app.advance(999)
  assert(app.contains("ticks=0"))
  app.advance(1)
  assert(app.contains("ticks=1 clock"))
  app.advance(2500)
  assert(app.contains("ticks=2"))
  app.key("x")
  app.advance(5000)
  assert(app.contains("ticks=2"))
end

fun test_a_one_shot_timer_fires_once()
  let app = t.Harness.start(30, 4, counter())
  app.key("o")
  app.advance(600)
  assert(app.contains("ticks=1 once"))
  app.advance(5000)
  assert(app.contains("ticks=1 once"))
end

fun test_a_resize_redraws_everything_at_the_new_size()
  let app = t.Harness.start(20, 4, counter())
  app.resize(30, 6)
  assert_eq(app.line(2), " 30x6")
  assert_eq(app.buffer().rows, 6)
  assert(app.output()[app.output().len() - 1].starts_with("\e[0m\e[2J"))
end

fun test_the_title_and_the_cursor_are_written_when_they_change()
  let app = t.Harness.start(20, 4, counter())
  app.key("T")
  assert(app.output()[app.output().len() - 1].contains("\e]0;Counter 0\e\\"))
  app.key("c")
  let last = app.output()[app.output().len() - 1]
  assert(last.contains("\e[2;4H\e[?25h"))
  app.key("+")
  assert(app.output()[app.output().len() - 1].contains("\e[2;4H"))
end

fun test_the_first_picture_hides_the_cursor_when_the_program_has_none()
  let app = t.Harness.start(20, 4, counter())
  assert(app.output()[0].ends_with("\e[?25l"))
end

fun test_input_helpers_send_the_matching_events()
  let app = t.Harness.start(20, 4, counter())
  app.text("+++")
  app.paste("ignored")
  app.click(1, 1)
  app.wheel(1, 1, true)
  assert(app.contains("n=3"))
end
