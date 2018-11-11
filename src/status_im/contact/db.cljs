(ns status-im.contact.db
  (:require [cljs.spec.alpha :as spec]
            [status-im.js-dependencies :as js-dependencies]
            [status-im.utils.gfycat.core :as gfycat]
            [status-im.utils.identicon :as identicon]
            status-im.utils.db))

;;;; DB

;;Contact

;;we can't validate public key, because for dapps public-key is just string
(spec/def :contact/public-key :global/not-empty-string)
(spec/def :contact/name (spec/nilable :global/not-empty-string))
(spec/def :contact/address (spec/nilable :global/address))
(spec/def :contact/photo-path (spec/nilable string?))
(spec/def :contact/status (spec/nilable string?))
(spec/def :contact/fcm-token (spec/nilable string?))
(spec/def :contact/description (spec/nilable string?))

(spec/def :contact/last-updated (spec/nilable int?))
(spec/def :contact/last-online (spec/nilable int?))
(spec/def :contact/pending? boolean?)
(spec/def :contact/unremovable? boolean?)
(spec/def :contact/hide-contact? boolean?)

(spec/def :contact/dapp? boolean?)
(spec/def :contact/dapp-url (spec/nilable string?))
(spec/def :contact/dapp-hash (spec/nilable int?))
(spec/def :contact/bot-url (spec/nilable string?))
(spec/def :contact/command (spec/nilable (spec/map-of int? map?)))
(spec/def :contact/response (spec/nilable (spec/map-of int? map?)))
(spec/def :contact/subscriptions (spec/nilable map?))
;;true when contact added using status-dev-cli
(spec/def :contact/debug? boolean?)

(spec/def :contact/contact (spec/keys  :req-un [:contact/public-key]
                                       :opt-un [:contact/name
                                                :contact/address
                                                :contact/photo-path
                                                :contact/status
                                                :contact/last-updated
                                                :contact/last-online
                                                :contact/pending?
                                                :contact/hide-contact?
                                                :contact/unremovable?
                                                :contact/dapp?
                                                :contact/dapp-url
                                                :contact/dapp-hash
                                                :contact/bot-url
                                                :contact/command
                                                :contact/response
                                                :contact/debug?
                                                :contact/subscriptions
                                                :contact/fcm-token
                                                :contact/description
                                                :status/tags]))

;;Contact list ui props
(spec/def :contact-list-ui/edit? boolean?)

;;Contacts ui props
(spec/def :contacts-ui/edit? boolean?)

(spec/def :contacts/contacts (spec/nilable (spec/map-of :global/not-empty-string :contact/contact)))
;;public key of new contact during adding this new contact
(spec/def :contacts/new-identity (spec/nilable string?))
(spec/def :contacts/new-identity-error (spec/nilable string?))
;;on showing this contact's profile (andrey: better to move into profile ns)
(spec/def :contacts/identity (spec/nilable :global/not-empty-string))
(spec/def :contacts/list-ui-props (spec/nilable (spec/keys :opt-un [:contact-list-ui/edit?])))
(spec/def :contacts/ui-props (spec/nilable (spec/keys :opt-un [:contacts-ui/edit?])))
;;used in modal list (for example for wallet)
(spec/def :contacts/click-handler (spec/nilable fn?))
;;used in modal list (for example for wallet)
(spec/def :contacts/click-action (spec/nilable #{:send :request}))
;;used in modal list (for example for wallet)
(spec/def :contacts/click-params (spec/nilable map?))

(spec/def :contact/new-tag string?)
(spec/def :ui/contact (spec/keys :opt [:contact/new-tag]))

(defn public-key->new-contact
  [public-key]
  {:name       (gfycat/generate-gfy public-key)
   :photo-path (identicon/identicon public-key)
   :public-key public-key
   :tags       #{}})

(defn public-key->contact
  [contacts public-key]
  (when public-key
    (get contacts public-key
         (public-key->new-contact public-key))))

(defn public-key->address [public-key]
  (let [length (count public-key)
        normalized-key (case length
                         132 (subs public-key 4)
                         130 (subs public-key 2)
                         128 public-key
                         nil)]
    (when normalized-key
      (subs (.sha3 js-dependencies/Web3.prototype normalized-key (clj->js {:encoding "hex"})) 26))))

(defn address->contact
  [contacts address]
  (some #(contact-by-address % address) contacts))

(defn blocked?
  [{:keys [tags] :or {tags #{}}}]
  (tags "blocked"))

(defn blocked-contacts
  [contacts]
  (set (keep #(when (blocked? %)
                (:public-key %))
             (vals contacts))))

(defn- enrich-contact
  [{:keys [public-key] :as contact}]
  (cond-> contact
    (blocked? contact) (assoc :blocked? true)))

(defn enrich-contacts
  [contacts]
  (reduce-kv #(assoc %1 %2 (enrich-contact %3))
             {}
             contacts))
