#!/usr/bin/env python3
"""
Agent Handoff Graph Validator

Validates the agent registry for:
- Circular dependencies
- Missing agents
- Orphaned agents
- Handoff contract violations
- Cost anomalies
- Context requirement mismatches
"""

import sys
import yaml
import json
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional
from dataclasses import dataclass, asdict
from collections import defaultdict, deque


@dataclass
class ValidationError:
    """Represents a validation error or warning"""
    severity: str  # critical, high, medium, low
    rule: str
    agent: Optional[str]
    message: str
    details: Optional[str] = None

    def to_dict(self):
        return asdict(self)


class AgentHandoffGraph:
    """Analyzes handoff relationships between agents"""

    def __init__(self, registry: Dict):
        self.registry = registry
        self.agents = registry.get("agents", {})
        self.pipelines = registry.get("pipelines", {})
        self.validation_rules = registry.get("validation_rules", [])
        self.errors: List[ValidationError] = []
        self.warnings: List[ValidationError] = []

    def validate(self) -> Tuple[bool, List[ValidationError]]:
        """Run all validations"""
        self._validate_agent_existence()
        self._validate_handoff_contracts()
        self._validate_no_cycles()
        self._validate_reachability()
        self._validate_context_requirements()
        self._validate_cost_anomalies()
        self._validate_documentation()

        has_critical = any(e.severity == "critical" for e in self.errors)
        return not has_critical, self.errors + self.warnings

    def _validate_agent_existence(self):
        """Check that all referenced agents exist"""
        known_agents = set(self.agents.keys())

        for agent_name, agent in self.agents.items():
            for handoff in agent.get("handoffs", {}).get("to", []):
                target = handoff.get("name")
                if target and target not in ["any-agent", "chromadb", "user"]:
                    if target not in known_agents:
                        self.errors.append(ValidationError(
                            severity="high",
                            rule="all_agents_exist",
                            agent=agent_name,
                            message=f"Agent '{agent_name}' hands off to non-existent agent '{target}'",
                            details=f"Available agents: {', '.join(sorted(known_agents))}"
                        ))

            for handoff in agent.get("handoffs", {}).get("from", []):
                source = handoff.get("name")
                if source and source not in ["user", "any-agent"]:
                    if source not in known_agents:
                        self.errors.append(ValidationError(
                            severity="high",
                            rule="all_agents_exist",
                            agent=agent_name,
                            message=f"Agent '{agent_name}' receives from non-existent agent '{source}'",
                            details=f"Available agents: {', '.join(sorted(known_agents))}"
                        ))

    def _validate_handoff_contracts(self):
        """Check that handoff relationships are symmetric"""
        for agent_name, agent in self.agents.items():
            for handoff in agent.get("handoffs", {}).get("to", []):
                target = handoff.get("name")
                if target in self.agents:
                    # Check if target accepts from this agent
                    target_agent = self.agents[target]
                    accepts = any(h.get("name") == agent_name
                                for h in target_agent.get("handoffs", {}).get("from", []))
                    if not accepts:
                        self.warnings.append(ValidationError(
                            severity="medium",
                            rule="handoff_contracts_match",
                            agent=agent_name,
                            message=f"Agent '{agent_name}' hands to '{target}', but '{target}' doesn't list '{agent_name}' in 'from'",
                            details="Add '{agent_name}' to handoffs.from for '{target}'"
                        ))

    def _validate_no_cycles(self):
        """Detect circular dependencies using DFS"""
        visited = set()
        rec_stack = set()
        cycles = []

        def dfs(node: str, path: List[str]):
            visited.add(node)
            rec_stack.add(node)
            path.append(node)

            agent = self.agents.get(node)
            if agent:
                for handoff in agent.get("handoffs", {}).get("to", []):
                    neighbor = handoff.get("name")
                    if neighbor in self.agents:
                        if neighbor not in visited:
                            dfs(neighbor, path[:])
                        elif neighbor in rec_stack:
                            # Cycle detected
                            cycle_start = path.index(neighbor)
                            cycle = path[cycle_start:] + [neighbor]
                            cycles.append(cycle)

            rec_stack.remove(node)

        for agent_name in self.agents:
            if agent_name not in visited:
                dfs(agent_name, [])

        if cycles:
            for cycle in cycles:
                self.errors.append(ValidationError(
                    severity="critical",
                    rule="no_cycles",
                    agent=None,
                    message=f"Circular dependency detected: {' -> '.join(cycle)}",
                    details="Cycles break orchestration logic. Review handoff relationships."
                ))

    def _validate_reachability(self):
        """Check that all agents appear in at least one pipeline"""
        documented_agents = set()
        for pipeline in self.pipelines.values():
            documented_agents.update(pipeline.get("stages", []))

        # Also consider agents in handoff relationships
        connected_agents = set()
        for agent_name, agent in self.agents.items():
            if agent.get("handoffs", {}).get("to") or agent.get("handoffs", {}).get("from"):
                connected_agents.add(agent_name)

        orphaned = set(self.agents.keys()) - documented_agents - connected_agents

        for agent in orphaned:
            agent_obj = self.agents.get(agent, {})
            status = agent_obj.get("status", "active")
            if status != "external" and status != "meta":
                self.warnings.append(ValidationError(
                    severity="medium",
                    rule="all_agents_reachable",
                    agent=agent,
                    message=f"Agent '{agent}' doesn't appear in any documented pipeline",
                    details="Add agent to an appropriate pipeline or verify it's intentionally standalone"
                ))

    def _validate_context_requirements(self):
        """Check context flow through handoffs"""
        for agent_name, agent in self.agents.items():
            requires = agent.get("context_requirements", {})

            # Check upstream agents provide required context
            for handoff in agent.get("handoffs", {}).get("from", []):
                source = handoff.get("name")
                if source in self.agents:
                    source_agent = self.agents[source]
                    source_provides = source_agent.get("context_requirements", {})

                    if requires.get("chromadb") and not source_provides.get("chromadb"):
                        self.warnings.append(ValidationError(
                            severity="low",
                            rule="context_requirements_met",
                            agent=agent_name,
                            message=f"'{agent_name}' requires ChromaDB but upstream '{source}' may not provide it",
                            details="Ensure ChromaDB is initialized before handoff"
                        ))

    def _validate_cost_anomalies(self):
        """Flag expensive pipelines for review"""
        cost_multipliers = self.registry.get("statistics", {}).get("cost_multipliers", {})

        for pipeline_name, pipeline in self.pipelines.items():
            stages = pipeline.get("stages", [])
            total_cost = 0

            for stage in stages:
                if stage in self.agents:
                    agent = self.agents[stage]
                    model = agent.get("model", "sonnet")
                    multiplier = cost_multipliers.get(model, 1.0)
                    tokens = agent.get("cost_model", {}).get("typical_tokens_per_operation", 0)
                    # Rough estimate: $0.003 per 1k tokens for sonnet
                    cost_estimate = (tokens / 1000) * 0.003 * multiplier
                    total_cost += cost_estimate

            if total_cost > 2.0:
                self.warnings.append(ValidationError(
                    severity="low",
                    rule="cost_reasonable",
                    agent=None,
                    message=f"Pipeline '{pipeline_name}' estimated cost ${total_cost:.2f} is high",
                    details=f"Stages: {' -> '.join(stages)}. Consider breaking into smaller tasks."
                ))

    def _validate_documentation(self):
        """Check that handoffs in pipelines are documented"""
        for pipeline_name, pipeline in self.pipelines.items():
            stages = pipeline.get("stages", [])
            for i, stage in enumerate(stages[:-1]):
                next_stage = stages[i + 1]
                if stage in self.agents:
                    agent = self.agents[stage]
                    hands_to = [h.get("name") for h in agent.get("handoffs", {}).get("to", [])]
                    if next_stage not in hands_to:
                        self.warnings.append(ValidationError(
                            severity="medium",
                            rule="documented_pipelines",
                            agent=stage,
                            message=f"Pipeline '{pipeline_name}': '{stage}' -> '{next_stage}' not in handoff definitions",
                            details=f"Add handoff from '{stage}' to '{next_stage}' in agent registry"
                        ))

    def build_graph_viz(self) -> str:
        """Generate GraphViz representation of handoff graph"""
        lines = ["digraph AgentHandoffs {"]
        lines.append("  rankdir=LR;")
        lines.append("  node [shape=box];")

        # Add nodes with colors
        for agent_name, agent in self.agents.items():
            color = agent.get("color", "white")
            status = agent.get("status", "active")
            shape = "box" if status == "active" else "box3d"
            lines.append(f"  {agent_name} [label=\"{agent_name}\\n({agent.get('model', '?')})\", color={color}, shape={shape}];")

        # Add edges
        seen_edges = set()
        for agent_name, agent in self.agents.items():
            for handoff in agent.get("handoffs", {}).get("to", []):
                target = handoff.get("name")
                if target in self.agents:
                    edge_key = (agent_name, target)
                    if edge_key not in seen_edges:
                        lines.append(f"  {agent_name} -> {target};")
                        seen_edges.add(edge_key)

        lines.append("}")
        return "\n".join(lines)

    def generate_report(self) -> Dict:
        """Generate comprehensive validation report"""
        critical_errors = [e for e in self.errors if e.severity == "critical"]
        high_errors = [e for e in self.errors if e.severity == "high"]
        medium_warnings = [e for e in self.warnings if e.severity == "medium"]

        return {
            "summary": {
                "total_agents": len(self.agents),
                "total_errors": len(self.errors),
                "critical": len(critical_errors),
                "high": len(high_errors),
                "total_warnings": len(self.warnings),
                "medium": len(medium_warnings),
                "pass": len(self.errors) == 0
            },
            "errors": [e.to_dict() for e in self.errors],
            "warnings": [e.to_dict() for e in self.warnings],
            "pipelines": {
                name: {
                    "stages": pipeline.get("stages", []),
                    "estimated_cost": pipeline.get("estimated_cost", "unknown"),
                    "purpose": pipeline.get("purpose", "")
                }
                for name, pipeline in self.pipelines.items()
            },
            "agent_summary": {
                name: {
                    "category": agent.get("category", "unknown"),
                    "model": agent.get("model", "unknown"),
                    "status": agent.get("status", "active"),
                    "handoff_to": [h.get("name") for h in agent.get("handoffs", {}).get("to", [])],
                    "receives_from": [h.get("name") for h in agent.get("handoffs", {}).get("from", [])]
                }
                for name, agent in self.agents.items()
            }
        }


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python3 validate-handoff-graph.py <path-to-registry.yaml> [--json] [--graphviz]")
        sys.exit(1)

    registry_path = Path(sys.argv[1])
    if not registry_path.exists():
        print(f"Error: Registry file not found: {registry_path}")
        sys.exit(1)

    # Parse arguments
    json_output = "--json" in sys.argv
    graphviz_output = "--graphviz" in sys.argv

    # Load registry
    with open(registry_path, 'r') as f:
        registry = yaml.safe_load(f)

    # Validate
    graph = AgentHandoffGraph(registry)
    is_valid, all_issues = graph.validate()

    # Generate report
    report = graph.generate_report()

    # Output
    if json_output:
        print(json.dumps(report, indent=2))
    else:
        # Human-readable output
        print("=" * 80)
        print("AGENT HANDOFF GRAPH VALIDATION REPORT")
        print("=" * 80)
        print()

        summary = report["summary"]
        print(f"Total Agents:  {summary['total_agents']}")
        print(f"Status:        {'PASS' if summary['pass'] else 'FAIL'}")
        print()

        if summary["critical"] > 0:
            print(f"CRITICAL ERRORS: {summary['critical']}")
            for error in report["errors"]:
                if error["severity"] == "critical":
                    print(f"  - {error['message']}")
                    if error["details"]:
                        print(f"    Details: {error['details']}")
            print()

        if summary["high"] > 0:
            print(f"HIGH ERRORS: {summary['high']}")
            for error in report["errors"]:
                if error["severity"] == "high":
                    print(f"  - [{error['agent']}] {error['message']}")
                    if error["details"]:
                        print(f"    Details: {error['details']}")
            print()

        if summary["medium"] > 0:
            print(f"MEDIUM WARNINGS: {summary['medium']}")
            for warning in report["warnings"]:
                if warning["severity"] == "medium":
                    print(f"  - [{warning['agent']}] {warning['message']}")
            print()

        print(f"Total Warnings: {summary['total_warnings']}")
        print()

        # Pipelines
        if report["pipelines"]:
            print("DOCUMENTED PIPELINES:")
            for name, pipeline in report["pipelines"].items():
                print(f"  - {name}: {' -> '.join(pipeline['stages'])}")
            print()

    if graphviz_output:
        graphviz = graph.build_graph_viz()
        print("\nGraphViz Output:")
        print(graphviz)

    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()
