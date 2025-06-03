import NavMenu from "./nav_menu"
import Modal from "./modal"
import ResetForm from "./reset_form"
import ForceLogout from "./force_logout"
import ChatHooks from "./chat"
import DialogDrawerMode from "./dialog_drawer_mode"
import FeatureRequestEvents from "./feature_request_events"

export default {
  NavMenu,
  Modal,
  ResetForm,
  ForceLogout,
  DialogDrawerMode,
  FeatureRequestEvents,
  ...ChatHooks
}
