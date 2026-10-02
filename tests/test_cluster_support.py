#!/usr/bin/env python3
"""Local regression checks; no cluster jobs or bioinformatics tools are used."""
import importlib.util
import json
import gzip
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("workflow", ROOT / "scripts/cluster_workflow.py")
workflow = importlib.util.module_from_spec(spec)
spec.loader.exec_module(workflow)


class PipelineChecks(unittest.TestCase):
    def test_shared_pipeline_contract_with_paired_and_single_samples(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            tools = root / "bin"
            tools.mkdir()
            mock = ROOT / "tests/mock_pipeline_tool.py"
            mock.chmod(0o755)
            for name in ["bwa", "samtools", "gatk", "bcftools", "fastqc", "fastp", "multiqc"]:
                (tools / name).symlink_to(mock)
            for name in ["P_R1", "P_R2", "S_R1"]:
                with gzip.open(root / (name + ".fastq.gz"), "wt") as stream:
                    stream.write("@r1\nACGT\n+\nIIII\n")
            reference = root / "ref.fa"
            for suffix in [".fa", ".fa.bwt", ".fa.fai", ".dict"]:
                (root / ("ref" + suffix)).write_text("test reference\n")
            sheet = root / "sheet.csv"
            sheet.write_text("sample_id,condition,replicate,library_type,r1_fastq,r2_fastq,sex,extra\n"
                             f"P,affected,1,paired,{root}/P_R1.fastq.gz,{root}/P_R2.fastq.gz,female,extra\n"
                             f"S,unaffected,1,single,{root}/S_R1.fastq.gz,,male,extra\n")
            env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ["PATH"],
                       REF=str(reference), THREADS="4", TOOL_TRACE=str(root / "trace.jsonl"))
            out = root / "out"
            for sample in ["P", "S"]:
                result = subprocess.run(["bash", str(ROOT / "run_sample.sh"), str(sheet), str(out), sample], env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
            before = [json.loads(line) for line in (root / "trace.jsonl").read_text().splitlines()]
            result = subprocess.run(["bash", str(ROOT / "run_pipeline.sh"), str(sheet), str(out)], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            after = [json.loads(line) for line in (root / "trace.jsonl").read_text().splitlines()]
            # The cohort must reuse successful sample stages, not run align/call again.
            self.assertEqual(sum("HaplotypeCaller" in row for row in before), 2)
            self.assertEqual(sum("HaplotypeCaller" in row for row in after), 2)
            manifest = json.loads((out / "results/manifest.json").read_text())
            self.assertEqual({s["sample_id"] for s in manifest["samples"]}, {"P", "S"})
            self.assertTrue((out / "results/cohort.filtered.vcf.gz").is_file())
            self.assertFalse(list((out / "gvcf").glob("*.tmp.g.vcf.gz")))

    def test_named_columns_empty_r2_and_sample_selection(self):
        with tempfile.TemporaryDirectory() as folder:
            sheet = Path(folder) / "sheet.csv"
            sheet.write_text("sex,r2_fastq,condition,sample_id,r1_fastq,replicate,library_type,extra\r\n"
                             "female,,unaffected,S1,/course/r1.fq.gz,1,single,metadata\r\n"
                             "male,/course/p2.fq.gz,affected,S2,/course/p1.fq.gz,2,paired,metadata\r\n")
            result = subprocess.run(["bash", "-c", 'source "$1"; rows "$2" S1', "test", str(ROOT / "lib/common.sh"), str(sheet)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "S1,unaffected,1,single,/course/r1.fq.gz,\n")

    def test_bad_sheet_fails_before_any_stage(self):
        with tempfile.TemporaryDirectory() as folder:
            sheet = Path(folder) / "bad.csv"
            sheet.write_text("sample_id,r1_fastq\nS1,/missing\n")
            result = subprocess.run(["bash", str(ROOT / "run_sample.sh"), str(sheet), folder + "/out", "S1", "validate"], text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing samplesheet column", result.stderr)
            self.assertNotIn("=====", result.stderr)

    def test_empty_sample_and_cohort_stage_are_refused(self):
        for sample, stage in [("", "validate"), ("S1", "merge"), ("S1", "publish")]:
            result = subprocess.run(["bash", str(ROOT / "run_sample.sh"), "/missing", "/missing", sample, stage], capture_output=True)
            self.assertEqual(result.returncode, 64)

    def test_partial_output_does_not_get_success_checkpoint(self):
        with tempfile.TemporaryDirectory() as folder:
            script = '''set -euo pipefail
source "$1"
SAMPLE=S1 STATE=$2 RUN_KEY=test-key
mkdir -p "$STATE"
stage_align() { echo partial > "$STATE/partial.bam"; false; }
run_stage align
'''
            result = subprocess.run(["bash", "-c", script, "test", str(ROOT / "lib/common.sh"), folder], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue((Path(folder) / "partial.bam").exists())
            self.assertFalse((Path(folder) / "S1.align.done").exists())

    def test_success_skips_then_changed_config_runs_again(self):
        with tempfile.TemporaryDirectory() as folder:
            script = '''set -euo pipefail
source "$1"
SAMPLE=S1 STATE=$2 RUN_KEY=first
mkdir -p "$STATE"
stage_validate() { echo ran >> "$STATE/calls"; }
run_stage validate
run_stage validate
RUN_KEY=changed
run_stage validate
'''
            result = subprocess.run(["bash", "-c", script, "test", str(ROOT / "lib/common.sh"), folder], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((Path(folder) / "calls").read_text(), "ran\nran\n")


class WorkflowChecks(unittest.TestCase):
    def test_accounting_units_and_states(self):
        self.assertEqual(workflow.seconds("1-02:03:04"), 93784)
        self.assertEqual(workflow.seconds("02:30.5"), 150.5)
        self.assertEqual(workflow.memory_bytes("6.5G"), 6.5 * 1024 ** 3)
        self.assertEqual(workflow.memory_bytes("2048Mc"), 2 * 1024 ** 3)
        self.assertEqual(workflow.state_name("CANCELLED by 123"), "CANCELLED")

    def test_core_choice_uses_time_comparison_and_memory_headroom(self):
        rows = [{"cpus": c, "elapsed": t, "peak": 10 * 1024 ** 3} for c, t in [(4, 400), (8, 210), (16, 200)]]
        self.assertEqual(workflow.choose_resources(rows), {"cpus": 8, "mem": "18G", "time": "00:30:00"})
        for row in rows:
            row["peak"] = 0
        with self.assertRaises(RuntimeError):
            workflow.choose_resources(rows)

    def test_submission_is_resumable_and_dependency_is_afterok(self):
        with tempfile.TemporaryDirectory() as folder:
            flow = workflow.Workflow({"PARTITION": "courses", "ACCOUNT": "course"}, Path(folder) / "evidence", 100)
            calls = []

            def fake(args, **kwargs):
                calls.append(args)
                return subprocess.CompletedProcess(args, 0, "12345;cluster\n", "")

            with patch.object(workflow, "command", fake):
                self.assertEqual(flow.submit("cohort", Path(folder), dependency="1000"), "12345")
                self.assertEqual(flow.submit("cohort", Path(folder), dependency="1000"), "12345")
            self.assertEqual(len(calls), 1)
            self.assertIn("--dependency=afterok:1000", calls[0])
            self.assertIn("--kill-on-invalid-dep=yes", calls[0])
            restored = workflow.Workflow({}, Path(folder) / "evidence", 100)
            self.assertEqual(restored.state["jobs"]["cohort"]["id"], "12345")

    def test_completed_job_can_disappear_from_squeue(self):
        with tempfile.TemporaryDirectory() as folder:
            flow = workflow.Workflow({}, Path(folder) / "evidence", 10)
            flow.state["jobs"]["one"] = {"id": "12", "array": "1"}
            rows = [{"JobID": "12_1", "State": "COMPLETED"}]
            missing = subprocess.CompletedProcess([], 1, "", "Invalid job id specified")
            with patch.object(workflow, "command", return_value=missing), patch.object(flow, "accounting", return_value=rows), patch.object(flow, "collect"):
                self.assertEqual(flow.wait("one"), rows)


if __name__ == "__main__":
    unittest.main()
