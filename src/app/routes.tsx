import { createBrowserRouter } from "react-router";
import { Dashboard } from "./pages/Dashboard";
import { Editor } from "./pages/Editor";
import { GraphView } from "./pages/GraphView";
import { ErrorBoundary } from "./components/ErrorBoundary";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Dashboard,
    errorElement: <ErrorBoundary />,
  },
  {
    path: "/note/:id",
    Component: Editor,
    errorElement: <ErrorBoundary />,
  },
  {
    path: "/graph/:id",
    Component: GraphView,
    errorElement: <ErrorBoundary />,
  },
]);