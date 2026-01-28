#!/usr/bin/env python3
"""
Agent Registry Tool

Provides CLI interface for querying and managing the agent registry.
Supports:
- List agents with filters
- Show agent details
- Query agent capabilities
- Visualize handoff pipelines
- Search agents
"""

import sys
import json
import yaml
from pathlib import Path
from typing import List, Dict, Optional

try:
    from tabulate import tabulate
except ImportError:
    # Fallback if tabulate not installed
    def tabulate(data, headers, tablefmt="grid"):
        if not data:
            return "No results."

        # Handle both dict and list-of-lists formats
        if data and isinstance(data[0], dict):
            rows = [[row.get(h, "") for h in headers] for row in data]
        else:
            rows = data

        col_widths = {h: len(str(h)) for h in headers}
        for row in rows:
            for i, h in enumerate(headers):
                col_widths[h] = max(col_widths[h], len(str(row[i] if i < len(row) else "")))

        # Simple ASCII table
        lines = []
        header_row = " | ".join(f"{h:<{col_widths[h]}}" for h in headers)
        lines.append(header_row)
        lines.append("-" * len(header_row))
        for row in rows:
            row_str = " | ".join(f"{str(row[i] if i < len(row) else ''):<{col_widths[h]}}"
                                for i, h in enumerate(headers))
            lines.append(row_str)
        return "\n".join(lines)


class AgentRegistry:
    """Manages agent registry queries"""

    def __init__(self, registry_path: str):
        with open(registry_path, 'r') as f:
            self.registry = yaml.safe_load(f)
        self.agents = self.registry.get("agents", {})
        self.pipelines = self.registry.get("pipelines", {})

    def list_agents(self, category: Optional[str] = None, status: Optional[str] = None) -> List[Dict]:
        """List agents with optional filtering"""
        results = []
        for name, agent in self.agents.items():
            if category and agent.get("category") != category:
                continue
            if status and agent.get("status") != status:
                continue
            results.append({
                "name": name,
                "category": agent.get("category", "unknown"),
                "model": agent.get("model", "?"),
                "status": agent.get("status", "active"),
                "description": agent.get("description", "")[:50] + "..."
            })
        return sorted(results, key=lambda x: x["name"])

    def show_agent(self, agent_name: str) -> Optional[Dict]:
        """Show detailed agent information"""
        if agent_name not in self.agents:
            return None

        agent = self.agents[agent_name]
        handoffs_to = [h.get("name") for h in agent.get("handoffs", {}).get("to", [])]
        handoffs_from = [h.get("name") for h in agent.get("handoffs", {}).get("from", [])]

        cost_model = agent.get("cost_model", {})
        cost_info = (
            f"{cost_model.get('model_tier', '?')} model, "
            f"~{cost_model.get('typical_tokens_per_operation', 0)} tokens/op, "
            f"{cost_model.get('estimated_cost_per_task', '?')}/task"
        )

        return {
            "name": agent_name,
            "category": agent.get("category", "unknown"),
            "model": agent.get("model", "?"),
            "color": agent.get("color", "default"),
            "status": agent.get("status", "active"),
            "description": agent.get("description", ""),
            "capabilities": agent.get("capabilities", []),
            "handoffs_to": handoffs_to,
            "handoffs_from": handoffs_from,
            "context_requirements": agent.get("context_requirements", {}),
            "cost_info": cost_info,
            "version": agent.get("version", "?")
        }

    def find_agents(self, query: str) -> List[Dict]:
        """Search agents by name, description, or capability"""
        query_lower = query.lower()
        results = []

        for name, agent in self.agents.items():
            match = False
            if query_lower in name.lower():
                match = True
            elif query_lower in agent.get("description", "").lower():
                match = True
            else:
                for cap in agent.get("capabilities", []):
                    if query_lower in cap.lower():
                        match = True
                        break

            if match:
                results.append({
                    "name": name,
                    "category": agent.get("category"),
                    "model": agent.get("model"),
                    "match_reason": "name" if query_lower in name else "capability"
                })

        return sorted(results, key=lambda x: x["name"])

    def show_pipeline(self, agent_name: str) -> Optional[List[str]]:
        """Show handoff pipeline starting from agent"""
        if agent_name not in self.agents:
            return None

        visited = set()
        path = []

        def traverse(name: str, depth: int = 0):
            if name in visited or depth > 10:
                return
            visited.add(name)
            path.append(("  " * depth) + name)

            agent = self.agents.get(name)
            if agent:
                for handoff in agent.get("handoffs", {}).get("to", []):
                    traverse(handoff.get("name"), depth + 1)

        traverse(agent_name)
        return path

    def validate_handoff(self, from_agent: str, to_agent: str) -> Dict:
        """Validate if handoff is possible"""
        if from_agent not in self.agents or to_agent not in self.agents:
            return {"valid": False, "error": "One or both agents not found"}

        from_obj = self.agents[from_agent]
        to_obj = self.agents[to_agent]

        # Check if from_agent hands to to_agent
        can_handoff = any(h.get("name") == to_agent
                         for h in from_obj.get("handoffs", {}).get("to", []))

        # Check if to_agent accepts from from_agent
        can_accept = any(h.get("name") == from_agent
                        for h in to_obj.get("handoffs", {}).get("from", []))

        return {
            "valid": can_handoff and can_accept,
            "from_agent": from_agent,
            "to_agent": to_agent,
            "can_handoff": can_handoff,
            "can_accept": can_accept,
            "from_model": from_obj.get("model"),
            "to_model": to_obj.get("model"),
            "handoff_type": next((h.get("contract_type") for h in from_obj.get("handoffs", {}).get("to", [])
                                 if h.get("name") == to_agent), "unknown")
        }

    def recommend_pipeline(self, task: str) -> Optional[List[str]]:
        """Recommend agent pipeline for a task"""
        task_lower = task.lower()

        # Simple recommendation engine
        recommendations = {
            "feature": ["strategic-planner", "plan-auditor", "java-architect-planner", "java-developer", "code-review-expert"],
            "bug": ["java-debugger", "java-developer", "code-review-expert", "test-validator"],
            "research": ["deep-research-synthesizer", "knowledge-tidier"],
            "architecture": ["codebase-deep-analyzer", "deep-analyst", "java-architect-planner", "plan-auditor"],
            "debug": ["codebase-deep-analyzer", "deep-analyst", "java-debugger", "java-developer"],
            "review": ["code-review-expert", "test-validator"],
            "planning": ["strategic-planner", "plan-auditor"],
            "refactor": ["codebase-deep-analyzer", "java-architect-planner", "java-developer", "code-review-expert"]
        }

        for keyword, pipeline in recommendations.items():
            if keyword in task_lower:
                return pipeline

        return None

    def agent_cost(self, agent_or_pipeline: str) -> Dict:
        """Show cost information"""
        multipliers = self.registry.get("statistics", {}).get("cost_multipliers", {})

        # Check if it's an agent
        if agent_or_pipeline in self.agents:
            agent = self.agents[agent_or_pipeline]
            cost_model = agent.get("cost_model", {})
            model = cost_model.get("model_tier", "?")
            return {
                "type": "agent",
                "name": agent_or_pipeline,
                "model": model,
                "multiplier": multipliers.get(model, 1.0),
                "typical_tokens": cost_model.get("typical_tokens_per_operation", 0),
                "estimated_cost": cost_model.get("estimated_cost_per_task", "?"),
                "relative_cost": cost_model.get("relative_cost", 1.0)
            }

        # Check if it's a pipeline
        if agent_or_pipeline in self.pipelines:
            pipeline = self.pipelines[agent_or_pipeline]
            total_cost = 0
            stages_cost = []

            for stage in pipeline.get("stages", []):
                if stage in self.agents:
                    agent = self.agents[stage]
                    model = agent.get("model", "sonnet")
                    multiplier = multipliers.get(model, 1.0)
                    tokens = agent.get("cost_model", {}).get("typical_tokens_per_operation", 0)
                    cost_estimate = (tokens / 1000) * 0.003 * multiplier  # $0.003 per 1k tokens for sonnet
                    total_cost += cost_estimate
                    stages_cost.append({"stage": stage, "cost": f"${cost_estimate:.2f}"})

            return {
                "type": "pipeline",
                "name": agent_or_pipeline,
                "stages": stages_cost,
                "total_estimated_cost": f"${total_cost:.2f}",
                "pipeline_cost": pipeline.get("estimated_cost", "?")
            }

        return {"error": f"Agent or pipeline '{agent_or_pipeline}' not found"}

    def get_statistics(self) -> Dict:
        """Get registry statistics"""
        stats = self.registry.get("statistics", {})
        return {
            "total_agents": len(self.agents),
            "total_pipelines": len(self.pipelines),
            **stats
        }


def print_table(data: List[Dict], title: str = ""):
    """Print data as formatted table"""
    if not data:
        print("No results.")
        return

    headers = list(data[0].keys())
    rows = [[d.get(h, "") for h in headers] for d in data]

    if title:
        print(f"\n{title}")
        print("-" * 80)

    print(tabulate(rows, headers=headers, tablefmt="grid"))


def main():
    """CLI entry point"""
    registry_path = Path(__file__).parent.parent / "agents" / "REGISTRY.yaml"

    if not registry_path.exists():
        print(f"Error: Registry not found at {registry_path}")
        sys.exit(1)

    registry = AgentRegistry(str(registry_path))

    # Parse commands
    if len(sys.argv) < 2:
        print("Agent Registry Tool - Usage:")
        print()
        print("  python3 agent-registry.py list [--category <type>] [--status <status>]")
        print("  python3 agent-registry.py show <agent-name>")
        print("  python3 agent-registry.py find <query>")
        print("  python3 agent-registry.py pipeline <agent-name>")
        print("  python3 agent-registry.py validate <from-agent> <to-agent>")
        print("  python3 agent-registry.py recommend <task-description>")
        print("  python3 agent-registry.py cost <agent-or-pipeline>")
        print("  python3 agent-registry.py stats")
        sys.exit(0)

    command = sys.argv[1]

    try:
        if command == "list":
            category = None
            status = None
            if "--category" in sys.argv:
                idx = sys.argv.index("--category")
                category = sys.argv[idx + 1]
            if "--status" in sys.argv:
                idx = sys.argv.index("--status")
                status = sys.argv[idx + 1]

            agents = registry.list_agents(category=category, status=status)
            print_table(agents, title=f"Agents (category={category}, status={status})")

        elif command == "show" and len(sys.argv) > 2:
            agent = registry.show_agent(sys.argv[2])
            if agent:
                print(f"\n{agent['name']} ({agent['category']}/{agent['model']})")
                print("-" * 80)
                print(f"Description: {agent['description']}")
                print(f"Status: {agent['status']}")
                print(f"Capabilities: {', '.join(agent['capabilities'])}")
                print(f"Cost Info: {agent['cost_info']}")
                print(f"Hands to: {', '.join(agent['handoffs_to']) if agent['handoffs_to'] else 'none'}")
                print(f"Receives from: {', '.join(agent['handoffs_from']) if agent['handoffs_from'] else 'none'}")
                print(f"Context Needs: ChromaDB={agent['context_requirements'].get('chromadb', False)}, "
                      f"MemoryBank={agent['context_requirements'].get('memory_bank', False)}, "
                      f"Beads={agent['context_requirements'].get('beads', False)}")
            else:
                print(f"Agent not found: {sys.argv[2]}")

        elif command == "find" and len(sys.argv) > 2:
            query = sys.argv[2]
            results = registry.find_agents(query)
            print_table(results, title=f"Search results for '{query}'")

        elif command == "pipeline" and len(sys.argv) > 2:
            agent = sys.argv[2]
            path = registry.show_pipeline(agent)
            if path:
                print(f"\nHandoff pipeline from {agent}:")
                print("-" * 80)
                for line in path:
                    print(line)
            else:
                print(f"Agent not found: {agent}")

        elif command == "validate" and len(sys.argv) > 3:
            result = registry.validate_handoff(sys.argv[2], sys.argv[3])
            print(f"\nHandoff validation: {sys.argv[2]} -> {sys.argv[3]}")
            print("-" * 80)
            print(f"Valid: {'YES' if result['valid'] else 'NO'}")
            if result.get("error"):
                print(f"Error: {result['error']}")
            else:
                print(f"Can handoff: {'YES' if result['can_handoff'] else 'NO'}")
                print(f"Can accept: {'YES' if result['can_accept'] else 'NO'}")
                print(f"Contract type: {result['handoff_type']}")

        elif command == "recommend" and len(sys.argv) > 2:
            task = " ".join(sys.argv[2:])
            pipeline = registry.recommend_pipeline(task)
            if pipeline:
                print(f"\nRecommended pipeline for '{task}':")
                print("-" * 80)
                print(" -> ".join(pipeline))
            else:
                print(f"No specific recommendation for '{task}'")

        elif command == "cost" and len(sys.argv) > 2:
            item = sys.argv[2]
            result = registry.agent_cost(item)
            print(f"\nCost information for '{item}':")
            print("-" * 80)
            print(json.dumps(result, indent=2))

        elif command == "stats":
            stats = registry.get_statistics()
            print("\nRegistry Statistics:")
            print("-" * 80)
            for key, value in stats.items():
                print(f"{key}: {value}")

        else:
            print(f"Unknown command: {command}")
            sys.exit(1)

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
