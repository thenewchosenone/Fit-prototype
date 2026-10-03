import { Component, type ErrorInfo, type ReactNode } from "react";

type Props = { children: ReactNode };
type State = { failed: boolean };

export class RouteErrorBoundary extends Component<Props, State> {
  state: State = { failed: false };

  static getDerivedStateFromError(): State {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("Unable to load route chunk", error, info.componentStack);
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <main className="page route-loading" role="alert">
        <strong>This page could not be loaded.</strong>
        <span>Check your connection and try again.</span>
        <button className="primary-button compact" onClick={() => window.location.reload()}>Try again</button>
      </main>
    );
  }
}
