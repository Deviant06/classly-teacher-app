// One-time seed: reproduces the original in-browser build() output and pushes it to Supabase.
// Run with: node scripts/seed-supabase.mjs
import { createClient } from "@supabase/supabase-js";
import ws from "ws";

const SUPABASE_URL = "https://obeeivvtaftjdequxubv.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9iZWVpdnZ0YWZ0amRlcXV4dWJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0NTA3NDcsImV4cCI6MjA5ODAyNjc0N30.XGnW2QckmYECxf5DUJ7SolHJaj4gJE7frfuCtT638Fw";

const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { realtime: { transport: ws } });

function rnd(s) {
  const x = Math.sin(s * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
}

const AVATARS = ["#6c4ad6","#1f9d6b","#e0921a","#3b82c4","#b14ad6","#2bb8a3","#d64a86","#e0533d","#7c5cd6","#4a9d6b"];

function build(subjectType = "Core Subject") {
  const fn = ["Maya","Liam","Sofia","Ethan","Aisha","Noah","Zoe","Diego","Priya","Marcus","Lena","Jamal","Chloe","Andre","Nina","Oscar","Hana","Tariq","Bella","Theo"];
  const ln = ["Rivera","Chen","Okafor","Patel","Nguyen","Santos","Kim","Mueller","Haddad","Brooks","Rossi","Webb","Adeyemi","Lopez","Volkov","Reyes","Tanaka","Bauer","Costa","Greene"];
  const students = fn.map((f, i) => ({
    id: "s" + i,
    name: f + " " + ln[i],
    first: f,
    initials: f[0] + ln[i][0],
    color: AVATARS[i % AVATARS.length],
    ability: 0.58 + rnd(i + 1) * 0.4,
    guardian: ln[i] + " household",
  }));

  const WT = {
    "Core Subject": [0.2, 0.5, 0.3],
    "Academic Elective": [0.2, 0.5, 0.3],
    "Immersion / Research": [0.15, 0.7, 0.15],
    "Specialized / Applied": [0.15, 0.65, 0.2],
    "Performance-based": [0.2, 0.8, 0.0],
  };
  const w = WT[subjectType] || WT["Core Subject"];
  const components = [
    { id: "ww", name: "Written Works", weight: w[0] },
    { id: "pt", name: "Performance Tasks", weight: w[1] },
    { id: "qa", name: "Quarterly Assessment", weight: w[2] },
  ];
  const tmpl = {
    ww: [["Written Work 1",20,"1"],["Written Work 2",15,"2"],["Written Work 3",20,"3"],["Written Work 4",10,"4"],["Written Work 5",25,"5"]],
    pt: [["Performance Task 1",50,"1"],["Performance Task 2",40,"2"],["Performance Task 3",30,"3"]],
    qa: [["Summative Assessment 1",25,"SA1"],["Summative Assessment 2",25,"SA2"],["Term Exam",50,"TE"]],
  };
  const assignments = [];
  for (let t = 0; t < 3; t++) {
    components.forEach((c) => {
      tmpl[c.id].forEach((a, i) => {
        assignments.push({ id: "t" + t + c.id + i, term: t, comp: c.id, name: a[0], hps: a[1], short: a[2] });
      });
    });
  }

  const scores = [];
  students.forEach((st, si) =>
    assignments.forEach((a, ai) => {
      const n = (rnd(si * 13 + ai * 7) - 0.5) * 0.22;
      const p = Math.max(0.45, Math.min(1, st.ability + n - a.term * 0.01));
      scores.push({ assignment_id: a.id, student_id: st.id, raw: Math.round(p * a.hps), flag: null });
    })
  );

  const standards = ["Cellular Processes","Genetics & Heredity","Scientific Method","Data Analysis","Ecology"].map((n, i) => ({ id: "st" + i, name: n }));
  const mastery = [];
  students.forEach((st, si) =>
    standards.forEach((sd, di) => {
      const level = Math.max(1, Math.min(4, 1 + Math.round(rnd(si * 5 + di * 3) * 3 * st.ability + 0.3)));
      mastery.push({ standard_id: sd.id, student_id: st.id, level });
    })
  );

  const periods = [
    { id: "p0", subject: "General Biology", period: "P2", room: "Rm 214", time: "9:05 AM", color: "#6c4ad6" },
    { id: "p1", subject: "General Chemistry", period: "P4", room: "Rm 118", time: "11:30 AM", color: "#2bb8a3" },
    { id: "p2", subject: "Earth Science", period: "P6", room: "Rm 203", time: "1:45 PM", color: "#e0921a" },
  ];

  return { students, assignments, scores, standards, mastery, periods, subjectType };
}

function seedAttendance(students) {
  const seq = ["present","present","present","late","present","present","absent","present","present","excused","present","present","late","present","present","present","absent","present","excused","present"];
  const rows = [];
  students.forEach((s, i) => {
    if (i !== 3 && i !== 13) rows.push({ att_date: "2026-06-19", period: 0, student_id: s.id, status: seq[i] });
  });
  return rows;
}

async function main() {
  const data = build("Core Subject");

  console.log("Seeding sections...");
  const { error: e1 } = await sb.from("sections").upsert(
    data.periods.map((p) => ({
      id: p.id,
      subject: p.subject,
      period: p.period,
      room: p.room,
      time: p.time,
      color: p.color,
      subject_type: data.subjectType,
    }))
  );
  if (e1) throw e1;

  console.log("Seeding students...");
  const { error: e2 } = await sb.from("students").upsert(
    data.students.map((s) => ({ id: s.id, name: s.name, first: s.first, initials: s.initials, color: s.color, guardian: s.guardian }))
  );
  if (e2) throw e2;

  console.log("Seeding assignments...");
  const { error: e3 } = await sb.from("assignments").upsert(data.assignments);
  if (e3) throw e3;

  console.log("Seeding scores...");
  for (let i = 0; i < data.scores.length; i += 500) {
    const { error } = await sb.from("scores").upsert(data.scores.slice(i, i + 500));
    if (error) throw error;
  }

  console.log("Seeding standards...");
  const { error: e4 } = await sb.from("standards").upsert(data.standards);
  if (e4) throw e4;

  console.log("Seeding mastery...");
  const { error: e5 } = await sb.from("mastery").upsert(data.mastery);
  if (e5) throw e5;

  console.log("Seeding attendance...");
  const att = seedAttendance(data.students);
  const { error: e6 } = await sb.from("attendance").upsert(att);
  if (e6) throw e6;

  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
