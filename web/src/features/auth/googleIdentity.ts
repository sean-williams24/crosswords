const googleIdentityScriptURL = "https://accounts.google.com/gsi/client";

type GoogleCredentialResponse = {
  credential?: string;
};

export type GoogleIdentity = {
  accounts: {
    id: {
      initialize: (configuration: {
        client_id: string;
        callback: (response: GoogleCredentialResponse) => void;
        auto_select: false;
      }) => void;
      renderButton: (parent: HTMLElement, options: {
        type: "standard";
        theme: "filled_black";
        size: "large";
        text: "signin_with";
        shape: "rectangular";
        logo_alignment: "left";
        width: number;
      }) => void;
    };
  };
};

type GoogleIdentityOptions = {
  clientID?: string;
  load?: () => Promise<GoogleIdentity>;
};

type GoogleIdentityHandlers = {
  onCredential: (idToken: string) => void;
  onError: (error: Error) => void;
};

let loadingGoogleIdentity: Promise<GoogleIdentity> | null = null;

export class GoogleIdentityConfigurationError extends Error {
  constructor(message = "Google Sign-In needs VITE_GOOGLE_WEB_CLIENT_ID before it can be used.") {
    super(message);
    this.name = "GoogleIdentityConfigurationError";
  }
}

function configuredClientID() {
  const clientID = import.meta.env.VITE_GOOGLE_WEB_CLIENT_ID;
  return typeof clientID === "string" && clientID ? clientID : undefined;
}

function existingGoogleIdentity() {
  return (window as Window & { google?: GoogleIdentity }).google;
}

function loadGoogleIdentity() {
  const existing = existingGoogleIdentity();
  if (existing) return Promise.resolve(existing);
  if (loadingGoogleIdentity) return loadingGoogleIdentity;

  const loader = new Promise<GoogleIdentity>((resolve, reject) => {
    const script = document.createElement("script");
    script.async = true;
    script.src = googleIdentityScriptURL;
    script.onload = () => {
      const google = existingGoogleIdentity();
      if (google) {
        resolve(google);
      } else {
        reject(new Error("Google Sign-In could not be loaded. Please try again."));
      }
    };
    script.onerror = () => reject(new Error("Google Sign-In could not be loaded. Please try again."));
    document.head.append(script);
  });

  loadingGoogleIdentity = loader;
  void loader.catch(() => {
    loadingGoogleIdentity = null;
  });

  return loader;
}

/// Renders Google's own sign-in button. Its browser-native account chooser
/// returns an ID token which Supabase can exchange without an OAuth redirect.
export async function renderGoogleSignInButton(
  parent: HTMLElement,
  handlers: GoogleIdentityHandlers,
  options: GoogleIdentityOptions = {}
) {
  const clientID = options.clientID ?? configuredClientID();
  if (!clientID) throw new GoogleIdentityConfigurationError();

  const google = await (options.load ?? loadGoogleIdentity)();
  google.accounts.id.initialize({
    client_id: clientID,
    auto_select: false,
    callback: ({ credential }) => {
      if (credential) {
        handlers.onCredential(credential);
      } else {
        handlers.onError(new Error("Google Sign-In did not return an identity token. Please try again."));
      }
    }
  });
  parent.replaceChildren();
  google.accounts.id.renderButton(parent, {
    type: "standard",
    theme: "filled_black",
    size: "large",
    text: "signin_with",
    shape: "rectangular",
    logo_alignment: "left",
    width: Math.min(375, Math.floor(parent.clientWidth || 375))
  });
}
